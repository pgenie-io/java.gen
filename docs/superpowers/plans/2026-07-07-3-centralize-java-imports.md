# Centralize the Java Import Block Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Structures/ImportSet.dhall` the single owner of "which flag produces which Java import line", fold the ad-hoc `needsCustomTypeImport : Bool` (threaded through 7 interpreter interfaces) into it as a proper member, and delete the two dead parameters (`needsArrayListImport`, `hasOptionalFields`) that `StatementModule`'s interface declares but never reads.

**Architecture:** Import knowledge currently lives in three shapes: ImportSet's four booleans; a `needsCustomTypeImport` flag produced in `Scalar` and re-aggregated in `Value`, `Member`, `ResultColumns`, `ResultRows`, `Result`, and `Query`; and flag→import-line mappings hardcoded twice (in `StatementModule` and `CustomCompositeTypeModule`, each with its own `importIf`). The refactor proceeds in three semantics-preserving stages: (A) add a `customTypes` member to ImportSet and switch `StatementModule`'s custom-types import line to read it; (B) delete the now-redundant `needsCustomTypeImport` field everywhere plus the dead template parameters; (C) move the flag→line mapping into `ImportSet.toImportLines` and use it from both templates. Composite type modules live in the `types` package themselves, so `CustomType` clears the `customTypes` flag before rendering — preserving the current output byte-for-byte.

**Tech Stack:** Dhall 1.42.3. Verification is `dhall type` on the whole tree plus a byte-for-byte golden diff of the generated demo output.

## Global Constraints

- **Prerequisites: plans 1 and 2 (`2026-07-07-1-…` and `2026-07-07-2-…`) must be fully applied.** This plan edits `gen/Interpreters/Member.dhall` (created by plan 1) and assumes `ColDecodeStatement`/`ParamBindStatement` are already deleted (plan 2).
- This is plan 3 of a 5-plan series.
- **Golden invariant:** generated output byte-identical to the baseline after every task. Import-line *order* inside generated files is part of the golden output — the flag order codecs → jsonNode → bigDecimal → uuid → customTypes must be preserved exactly.
- All commands run from the repo root. After editing any `.dhall` file: `dhall format <file>`.
- `demo-baseline/` and `demo-check/` are untracked scratch directories. Never commit them.
- Do not push. Commit per task with the messages given.

---

### Task 1: Capture the golden baseline

**Files:**
- Create: `demo-baseline/` (scratch, untracked)

**Interfaces:**
- Consumes: nothing.
- Produces: `demo-baseline/` for the golden diff used by all later tasks:
  `rm -rf demo-check && dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check && diff -r demo-baseline demo-check`

- [ ] **Step 1: Confirm clean tree and generate baseline**

```bash
git status --porcelain
rm -rf demo-baseline
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-baseline
find demo-baseline -type f | wc -l
```

Expected: no tracked changes; generation exits 0; file count `1093`.

---

### Task 2: Extend ImportSet with `customTypes` and `toImportLines`

**Files:**
- Modify: `gen/Structures/ImportSet.dhall` (full replacement below)

**Interfaces:**
- Consumes: nothing new.
- Produces: `ImportSet.Type` gains `customTypes : Bool`; new preset `ImportSet.customTypes`; new function `ImportSet.toImportLines : ImportSet.Type -> Text -> List Text` (second argument is the package name, used only for the custom-types line). Existing presets/`combine` keep their names, so all current callers keep compiling.

- [ ] **Step 1: Replace `gen/Structures/ImportSet.dhall` with this content**

```dhall
let Self =
      { codecs : Bool
      , jsonNode : Bool
      , bigDecimal : Bool
      , uuid : Bool
      , customTypes : Bool
      }

let empty
    : Self
    = { codecs = False
      , jsonNode = False
      , bigDecimal = False
      , uuid = False
      , customTypes = False
      }

let codecs
    : Self
    = empty // { codecs = True }

let jsonNode
    : Self
    = empty // { jsonNode = True }

let bigDecimal
    : Self
    = empty // { bigDecimal = True }

let uuid
    : Self
    = empty // { uuid = True }

let customTypes
    : Self
    = empty // { customTypes = True }

let combine =
      \(left : Self) ->
      \(right : Self) ->
        { codecs = left.codecs || right.codecs
        , jsonNode = left.jsonNode || right.jsonNode
        , bigDecimal = left.bigDecimal || right.bigDecimal
        , uuid = left.uuid || right.uuid
        , customTypes = left.customTypes || right.customTypes
        }

let importIf =
      \(condition : Bool) ->
      \(import : Text) ->
        if condition then [ import ] else [] : List Text

let toImportLines
    : Self -> Text -> List Text
    = \(self : Self) ->
      \(packageName : Text) ->
            importIf self.codecs "io.codemine.java.postgresql.codecs.*"
        #   importIf self.jsonNode "com.fasterxml.jackson.databind.JsonNode"
        #   importIf self.bigDecimal "java.math.BigDecimal"
        #   importIf self.uuid "java.util.UUID"
        #   importIf self.customTypes "${packageName}.types.*"

in  { Type = Self
    , empty
    , codecs
    , jsonNode
    , bigDecimal
    , uuid
    , customTypes
    , combine
    , toImportLines
    }
```

- [ ] **Step 2: Format, typecheck, golden diff**

```bash
dhall format gen/Structures/ImportSet.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL` (the new flag is `False` everywhere; `toImportLines` has no caller yet).

- [ ] **Step 3: Commit**

```bash
git add gen/Structures/ImportSet.dhall
git commit -m "refactor: ImportSet gains customTypes member and toImportLines rendering"
```

---

### Task 3: Stage A — carry the custom-types signal inside ImportSet

**Files:**
- Modify: `gen/Interpreters/Scalar.dhall` (Custom branch sets the flag)
- Modify: `gen/Interpreters/CustomType.dhall` (clear the flag for same-package rendering)
- Modify: `gen/Templates/StatementModule.dhall` (read the flag instead of the bool param)

**Interfaces:**
- Consumes: `ImportSet.customTypes` preset from Task 2.
- Produces: the custom-types import line in generated statement modules is now driven by `extraImports.customTypes` (which flows through the existing `imports` union) instead of the parallel `needsCustomTypeImport` booleans. The booleans still exist but are dead after this task; Task 4 deletes them.

- [ ] **Step 1: Set the flag at its source**

In `gen/Interpreters/Scalar.dhall`, in the `Custom` branch, replace:

```dhall
                      , imports = ImportSet.empty
```

with:

```dhall
                      , imports = ImportSet.customTypes
```

- [ ] **Step 2: Clear the flag where the file being generated lives in the `types` package itself**

In `gen/Interpreters/CustomType.dhall`, directly after the `extraImports` `List/fold` binding (the one that folds `member.imports` with `ImportSet.combine`), add:

```dhall
                                let moduleImports =
                                      extraImports // { customTypes = False }
```

and in the `Templates.CustomCompositeTypeModule.run` argument record change:

```dhall
                                          , extraImports
```

to:

```dhall
                                          , extraImports = moduleImports
```

(The `needsCodecsImport = extraImports.codecs` argument to the test template stays as is.)

- [ ] **Step 3: Read the flag in StatementModule**

In `gen/Templates/StatementModule.dhall`, replace the tail of the import list:

```dhall
                    # importIf params.extraImports.uuid "java.util.UUID"
                    # Deps.Prelude.List.unpackOptionals
                        Text
                        [ someIf
                            Text
                            params.needsCustomTypeImport
                            "${params.packageName}.types.*"
                        ]
```

with:

```dhall
                    # importIf params.extraImports.uuid "java.util.UUID"
                    # importIf
                        params.extraImports.customTypes
                        "${params.packageName}.types.*"
```

and delete the now-unused `someIf` helper:

```dhall
let someIf =
      \(V : Type) ->
      \(condition : Bool) ->
      \(v : V) ->
        if condition then Some v else None V
```

- [ ] **Step 4: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/Scalar.dhall gen/Interpreters/CustomType.dhall gen/Templates/StatementModule.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`. The flag reaches StatementModule through the same `imports` unions (`paramImports`, `resultInfo.imports`) that already aggregate the other four flags, so the emitted line set is unchanged.

- [ ] **Step 5: Commit**

```bash
git add gen/Interpreters/Scalar.dhall gen/Interpreters/CustomType.dhall gen/Templates/StatementModule.dhall
git commit -m "refactor: custom-types import travels inside ImportSet"
```

---

### Task 4: Stage B — delete `needsCustomTypeImport` and the dead template parameters

**Files:**
- Modify: `gen/Interpreters/Scalar.dhall`, `gen/Interpreters/Value.dhall`, `gen/Interpreters/Member.dhall`, `gen/Interpreters/ResultColumns.dhall`, `gen/Interpreters/ResultRows.dhall`, `gen/Interpreters/Result.dhall`, `gen/Interpreters/Query.dhall`, `gen/Templates/StatementModule.dhall`

**Interfaces:**
- Consumes: the Stage A state (nothing reads `needsCustomTypeImport` anymore).
- Produces: `needsCustomTypeImport` removed from every Output type; `StatementModule.Params` loses `needsCustomTypeImport : Bool`, `needsArrayListImport : Bool`, and `hasOptionalFields : Bool`; Query loses the four `let` blocks that existed only to feed those parameters. Later plans refer to the local binding `isMultipleCardinality` in Query — this task introduces that name (renamed from `needsArrayListImport`).

- [ ] **Step 1: Remove the field from the producer chain**

In `gen/Interpreters/Scalar.dhall`: delete `, needsCustomTypeImport : Bool` from `Output`; in the `Primitive` branch change the record extension

```dhall
                          { pgCastSuffix = None Text
                          , needsCustomTypeImport = False
                          }
```

to

```dhall
                          { pgCastSuffix = None Text }
```

and in the `Custom` branch delete the line `, needsCustomTypeImport = True`.

In `gen/Interpreters/Value.dhall`: delete `, needsCustomTypeImport : Bool` from `Output` and the line `, needsCustomTypeImport = scalar.needsCustomTypeImport` from **both** the array branch and the scalar branch.

In `gen/Interpreters/Member.dhall`: delete `, needsCustomTypeImport : Bool` from `Output` and `, needsCustomTypeImport = value.needsCustomTypeImport` from the combine record.

- [ ] **Step 2: Remove the field from the result chain**

In `gen/Interpreters/ResultColumns.dhall`: delete `, needsCustomTypeImport : Bool` from `Output`, the whole `let needsCustomTypeImport = Deps.Prelude.List.any … columns` binding, and `, needsCustomTypeImport` from the returned record.

In `gen/Interpreters/ResultRows.dhall`: delete `, needsCustomTypeImport : Bool` from the `Output` record type and `, needsCustomTypeImport = cols.needsCustomTypeImport` from the returned record.

In `gen/Interpreters/Result.dhall`: delete `, needsCustomTypeImport : Bool` from the `Output` record type and the line `, needsCustomTypeImport = False` from **both** the `Void` and `RowsAffected` branches.

- [ ] **Step 3: Prune Query**

In `gen/Interpreters/Query.dhall`:

Delete these four bindings entirely (they existed only to feed the dead template parameters):

- `let hasOptionalParam = …` (the `List.any … m.isOptional` block)
- `let hasOptionalResult = …` (the big `merge` over `input.result` checking member nullability)
- `let hasOptionalResultType = config.useOptional && isOptionalCardinality`
- `let needsCustomTypeImport = …` (the `List.any … m.needsCustomTypeImport || resultInfo.needsCustomTypeImport` block)

Keep `isOptionalCardinality` (still feeds the test template). Rename the `needsArrayListImport` binding to `isMultipleCardinality` — the binding body stays identical:

```dhall
        let isMultipleCardinality =
              merge
                { Void = False
                , RowsAffected = False
                , Rows =
                    \(rows : Deps.Sdk.Project.ResultRows) ->
                      merge
                        { Optional = False, Single = False, Multiple = True }
                        rows.cardinality
                }
                input.result
```

In the `Templates.StatementModule.run` argument record, delete these three lines:

```dhall
                , needsArrayListImport
```

```dhall
                , hasOptionalFields =
                        hasOptionalParam
                    ||  hasOptionalResult
                    ||  hasOptionalResultType
```

```dhall
                , needsCustomTypeImport
```

In the `Templates.StatementTestModule.run` argument record, change:

```dhall
                , isMultipleCardinality = needsArrayListImport
```

to:

```dhall
                , isMultipleCardinality
```

- [ ] **Step 4: Prune the StatementModule interface**

In `gen/Templates/StatementModule.dhall`, delete these three lines from `Params`:

```dhall
      , needsArrayListImport : Bool
```

```dhall
      , hasOptionalFields : Bool
```

```dhall
      , needsCustomTypeImport : Bool
```

- [ ] **Step 5: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/Scalar.dhall gen/Interpreters/Value.dhall gen/Interpreters/Member.dhall gen/Interpreters/ResultColumns.dhall gen/Interpreters/ResultRows.dhall gen/Interpreters/Result.dhall gen/Interpreters/Query.dhall gen/Templates/StatementModule.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
grep -rn "needsCustomTypeImport\|needsArrayListImport\|hasOptionalFields" gen/Interpreters gen/Templates/StatementModule.dhall ; echo "grep-done"
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK`; the grep prints nothing before `grep-done` (note: `hasOptionalFields` may still legitimately appear in `gen/Templates/CustomCompositeTypeModule.dhall` — that one is a local content-driven binding, not an interface parameter; it is out of scope); then `IDENTICAL`.

- [ ] **Step 6: Commit**

```bash
git add gen/Interpreters gen/Templates/StatementModule.dhall
git commit -m "refactor: delete needsCustomTypeImport threading and dead StatementModule params"
```

---

### Task 5: Stage C — both templates render flags via `toImportLines`

**Files:**
- Modify: `gen/Templates/StatementModule.dhall`
- Modify: `gen/Templates/CustomCompositeTypeModule.dhall`

**Interfaces:**
- Consumes: `ImportSet.toImportLines` from Task 2.
- Produces: neither template contains a flag→import-line mapping or an `importIf` helper anymore; adding a new flag-driven import in the future means touching only `ImportSet.dhall` (plus setting the flag at its source).

- [ ] **Step 1: Switch StatementModule**

In `gen/Templates/StatementModule.dhall`, replace the import-list expression:

```dhall
                  (   [ "java.sql.PreparedStatement"
                      , "java.sql.ResultSet"
                      , "java.sql.SQLException"
                      , "java.time.*"
                      , "java.util.ArrayList"
                      , "java.util.List"
                      , "java.util.Optional"
                      , "io.codemine.java.postgresql.jdbc.Codec"
                      , "io.codemine.java.postgresql.jdbc.Statement"
                      ]
                    # importIf
                        params.extraImports.codecs
                        "io.codemine.java.postgresql.codecs.*"
                    # importIf
                        params.extraImports.jsonNode
                        "com.fasterxml.jackson.databind.JsonNode"
                    # importIf
                        params.extraImports.bigDecimal
                        "java.math.BigDecimal"
                    # importIf params.extraImports.uuid "java.util.UUID"
                    # importIf
                        params.extraImports.customTypes
                        "${params.packageName}.types.*"
                  )
```

with:

```dhall
                  (   [ "java.sql.PreparedStatement"
                      , "java.sql.ResultSet"
                      , "java.sql.SQLException"
                      , "java.time.*"
                      , "java.util.ArrayList"
                      , "java.util.List"
                      , "java.util.Optional"
                      , "io.codemine.java.postgresql.jdbc.Codec"
                      , "io.codemine.java.postgresql.jdbc.Statement"
                      ]
                    # ImportSet.toImportLines
                        params.extraImports
                        params.packageName
                  )
```

and delete the now-unused local `importIf` helper:

```dhall
let importIf =
      \(condition : Bool) ->
      \(import : Text) ->
        if condition then [ import ] else [] : List Text
```

- [ ] **Step 2: Switch CustomCompositeTypeModule**

In `gen/Templates/CustomCompositeTypeModule.dhall`, replace the flag section of the `imports` binding:

```dhall
              # importIf
                  params.extraImports.codecs
                  "io.codemine.java.postgresql.codecs.*"
              # importIf
                  params.extraImports.jsonNode
                  "com.fasterxml.jackson.databind.JsonNode"
              # importIf params.extraImports.bigDecimal "java.math.BigDecimal"
              # importIf params.extraImports.uuid "java.util.UUID"
              # [ "io.codemine.java.postgresql.jdbc.Codec" ]
```

with:

```dhall
              # ImportSet.toImportLines params.extraImports params.packageName
              # [ "io.codemine.java.postgresql.jdbc.Codec" ]
```

and delete the local `importIf` helper:

```dhall
let importIf =
      \(condition : Bool) ->
      \(import : Text) ->
        if condition then [ import ] else [] : List Text
```

(The `hasOptionalFields || hasElementOptionalFields`-driven `java.util.Optional` entry above this section stays — it is derived from the fields being rendered, not from an ImportSet flag. The `customTypes` flag was cleared upstream in Task 3, so `toImportLines` adds no line here.)

- [ ] **Step 3: Format, typecheck, golden diff**

```bash
dhall format gen/Templates/StatementModule.dhall gen/Templates/CustomCompositeTypeModule.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL` (same flags, same order, same lines).

- [ ] **Step 4: Commit**

```bash
git add gen/Templates/StatementModule.dhall gen/Templates/CustomCompositeTypeModule.dhall
git commit -m "refactor: templates render import flags via ImportSet.toImportLines"
```

---

### Task 6: Full verification against the real build

**Files:**
- Modify: `demo-output/` (regenerated, untracked)

**Interfaces:**
- Consumes: everything above.
- Produces: end-to-end proof — the generated library compiles and its Testcontainers suite passes.

- [ ] **Step 1: Regenerate demo output and run the generated integration tests (requires Docker, ~minutes)**

```bash
rm -rf demo-output
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-output
cd demo-output && mvn -q verify && cd -
```

Expected: `BUILD SUCCESS`.

- [ ] **Step 2: Clean up scratch directories**

```bash
rm -rf demo-baseline demo-check
```
