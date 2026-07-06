# Deepen the Value Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Java decode/bind expression logic out of the `ColDecodeStatement` and `ParamBindStatement` templates and behind the Value interpreter's interface, so "how a PostgreSQL value crosses into Java" has one home.

**Architecture:** Today `Value.dhall` builds Java types and codec references, while two templates re-derive Optional wrapping/unwrapping from raw flags (`dims`, `isNullable`, `elementIsNullable`, `useOptional`, `isOptional`) that every intermediate module must shuttle. This plan gives `Value.Output` two function-valued members — `mkDecodeExpr` and `mkBindValueExpr` (the same shape `QueryFragments.Output.mkSqlExp` already uses) — and gives `Member.Output` two members that close over the member-level facts: `decodeStatement` and `bindStatement`. The two templates are then deleted and the raw flags `dims`/`elementIsNullable` leave `Member.Output`.

**Tech Stack:** Dhall 1.42.3 (records may contain function-typed fields). Verification is `dhall type` on the whole tree plus a byte-for-byte golden diff of the generated demo output.

## Global Constraints

- **Prerequisite: plan 1 (`2026-07-07-1-collapse-member-interpreters.md`) must be fully applied.** This plan edits `gen/Interpreters/Member.dhall`, which plan 1 creates.
- This is plan 2 of a 5-plan series.
- **Golden invariant:** generated output byte-identical to the baseline after every task.
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

### Task 2: Teach Value to render decode and bind expressions

**Files:**
- Modify: `gen/Interpreters/Value.dhall` (full replacement below)

**Interfaces:**
- Consumes: `Scalar.Output` (unchanged): `{ javaType, boxedJavaType, codecRef, imports, pgCastSuffix : Optional Text, needsCustomTypeImport, testDefaultLiteral, testRandomLiteral }`.
- Produces: `Value.Output` gains exactly two members, everything else unchanged:
  - `mkDecodeExpr : { isNullable : Bool, rowExpr : Text, colIdx : Text } -> Text` — the full right-hand side of a column decode, e.g. `Codec.INT4.decodeOptional(rs, row, 1)`.
  - `mkBindValueExpr : { isOptional : Bool, fieldAccess : Text } -> Text` — the value argument of a `bind(...)` call, e.g. `this.title().orElse(null)`.
  Task 3 wraps these in `Member.Output.decodeStatement`/`bindStatement`.

- [ ] **Step 1: Replace `gen/Interpreters/Value.dhall` with this content**

The expression logic is transplanted verbatim from `Templates/ColDecodeStatement.dhall:22-72` (the dims ladder and branch structure) and `Templates/ParamBindStatement.dhall:17-35` (the unwrap suffix), with template parameters replaced by values Value already knows (`config.useOptional`, the array settings, the codec ref):

```dhall
let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Lude = Deps.Lude

let Model = Deps.Sdk.Project

let Scalar = ./Scalar.dhall

let Input = Model.Value

let DecodeArgs = { isNullable : Bool, rowExpr : Text, colIdx : Text }

let BindArgs = { isOptional : Bool, fieldAccess : Text }

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , rawCodecType : Text
      , elementIsOptional : Bool
      , codecRef : Text
      , imports : ImportSet.Type
      , pgCastSuffix : Text
      , needsCustomTypeImport : Bool
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
      , mkDecodeExpr : DecodeArgs -> Text
      , mkBindValueExpr : BindArgs -> Text
      }

let optionalElementMapSuffix =
      \(dims : Natural) ->
        if    Deps.Prelude.Natural.equal dims 0
        then  ""
        else  if Deps.Prelude.Natural.equal dims 1
        then  ".map(list1 -> list1.stream().map(Optional::ofNullable).toList())"
        else  if Deps.Prelude.Natural.equal dims 2
        then  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(Optional::ofNullable).toList()).toList())"
        else  if Deps.Prelude.Natural.equal dims 3
        then  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(list3 -> list3.stream().map(Optional::ofNullable).toList()).toList()).toList())"
        else  if Deps.Prelude.Natural.equal dims 4
        then  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(list3 -> list3.stream().map(list4 -> list4.stream().map(Optional::ofNullable).toList()).toList()).toList()).toList())"
        else  if Deps.Prelude.Natural.equal dims 5
        then  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(list3 -> list3.stream().map(list4 -> list4.stream().map(list5 -> list5.stream().map(Optional::ofNullable).toList()).toList()).toList()).toList()).toList())"
        else  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(list3 -> list3.stream().map(list4 -> list4.stream().map(list5 -> list5.stream().map(list6 -> list6.stream().map(Optional::ofNullable).toList()).toList()).toList()).toList()).toList()).toList())"

let nonNullableElementMapSuffix =
      \(dims : Natural) ->
        Natural/fold
          (Deps.Prelude.Natural.subtract 1 dims)
          Text
          (\(inner : Text) -> ".stream().map(d -> d${inner}).toList()")
          ".stream().map(Optional::ofNullable).toList()"

let bindUnwrapSuffix =
      \(dims : Natural) ->
        Natural/fold
          (Deps.Prelude.Natural.subtract 1 dims)
          Text
          (\(inner : Text) -> ".stream().map(d -> d${inner}).toList()")
          ".stream().map(o -> o.orElse(null)).toList()"

let mkDecodeExprFor =
      \(useOptional : Bool) ->
      \(codecRef : Text) ->
      \(dims : Natural) ->
      \(elementIsNullable : Bool) ->
      \(args : DecodeArgs) ->
        if    args.isNullable
        then  if    useOptional
              then  let suffix =
                          if    elementIsNullable
                          then  optionalElementMapSuffix dims
                          else  ""

                    in  "${codecRef}.decodeOptional(rs, ${args.rowExpr}, ${args.colIdx})${suffix}"
              else  "${codecRef}.decodeNullable(rs, ${args.rowExpr}, ${args.colIdx})"
        else  if useOptional && elementIsNullable
        then  "${codecRef}.decodeNonNullable(rs, ${args.rowExpr}, ${args.colIdx})${nonNullableElementMapSuffix
                                                                                     dims}"
        else  "${codecRef}.decodeNonNullable(rs, ${args.rowExpr}, ${args.colIdx})"

let mkBindValueExprFor =
      \(useOptional : Bool) ->
      \(dims : Natural) ->
      \(elementIsNullable : Bool) ->
      \(args : BindArgs) ->
        let elementIsOptional = useOptional && elementIsNullable

        in  if    args.isOptional
            then  if    elementIsOptional
                  then  "${args.fieldAccess}.map(outer -> outer${bindUnwrapSuffix
                                                                   dims}).orElse(null)"
                  else  "${args.fieldAccess}.orElse(null)"
            else  if elementIsOptional
            then  "${args.fieldAccess} == null ? null : ${args.fieldAccess}${bindUnwrapSuffix
                                                                               dims}"
            else  args.fieldAccess

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Lude.Compiled.map
          Scalar.Output
          Output
          ( \(scalar : Scalar.Output) ->
              Deps.Prelude.Optional.fold
                Model.ArraySettings
                input.arraySettings
                Output
                ( \(arraySettings : Model.ArraySettings) ->
                    let elementIsOptional =
                          config.useOptional && arraySettings.elementIsNullable

                    let elementType =
                          if    elementIsOptional
                          then  "Optional<${scalar.boxedJavaType}>"
                          else  scalar.boxedJavaType

                    let arrayType =
                          Natural/fold
                            arraySettings.dimensionality
                            Text
                            (\(inner : Text) -> "List<${inner}>")
                            elementType

                    let rawArrayType =
                          Natural/fold
                            arraySettings.dimensionality
                            Text
                            (\(inner : Text) -> "List<${inner}>")
                            scalar.boxedJavaType

                    let inDimSuffix =
                          Natural/fold
                            arraySettings.dimensionality
                            Text
                            (\(inner : Text) -> "${inner}.inDim()")
                            "${scalar.codecRef}"

                    in  { javaType = arrayType
                        , boxedJavaType = arrayType
                        , rawCodecType = rawArrayType
                        , elementIsOptional
                        , codecRef = "${inDimSuffix}"
                        , imports = scalar.imports
                        , pgCastSuffix =
                            merge
                              { None = ""
                              , Some =
                                  \(suffix : Text) ->
                                        suffix
                                    ++  Deps.Prelude.Text.replicate
                                          arraySettings.dimensionality
                                          "[]"
                              }
                              scalar.pgCastSuffix
                        , needsCustomTypeImport = scalar.needsCustomTypeImport
                        , testDefaultLiteral = "List.of()"
                        , testRandomLiteral = "List.of()"
                        , mkDecodeExpr =
                            mkDecodeExprFor
                              config.useOptional
                              "${inDimSuffix}"
                              arraySettings.dimensionality
                              arraySettings.elementIsNullable
                        , mkBindValueExpr =
                            mkBindValueExprFor
                              config.useOptional
                              arraySettings.dimensionality
                              arraySettings.elementIsNullable
                        }
                )
                { javaType = scalar.javaType
                , boxedJavaType = scalar.boxedJavaType
                , rawCodecType = scalar.boxedJavaType
                , elementIsOptional = False
                , codecRef = scalar.codecRef
                , imports = scalar.imports
                , pgCastSuffix =
                    merge
                      { None = "", Some = \(suffix : Text) -> suffix }
                      scalar.pgCastSuffix
                , needsCustomTypeImport = scalar.needsCustomTypeImport
                , testDefaultLiteral = scalar.testDefaultLiteral
                , testRandomLiteral = scalar.testRandomLiteral
                , mkDecodeExpr =
                    mkDecodeExprFor config.useOptional scalar.codecRef 0 False
                , mkBindValueExpr = mkBindValueExprFor config.useOptional 0 False
                }
          )
          (Scalar.run config input.scalar)

in  Algebra.module Input Output run
```

- [ ] **Step 2: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/Value.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL` (the new members exist but nothing calls them yet).

- [ ] **Step 3: Commit**

```bash
git add gen/Interpreters/Value.dhall
git commit -m "refactor: Value renders its own decode and bind expressions"
```

---

### Task 3: Expose decode/bind statements on Member

**Files:**
- Modify: `gen/Interpreters/Member.dhall`

**Interfaces:**
- Consumes: `Value.Output.mkDecodeExpr` / `mkBindValueExpr` from Task 2.
- Produces: two new members on `Member.Output`:
  - `decodeStatement : { rowVarPresent : Bool, colIdx : Text } -> Text` — a complete Java local-declaration statement, e.g. `Optional<String> titleCol = Codec.TEXT.decodeOptional(rs, row, 1);`. The variable name is always `${fieldName}Col`.
  - `bindStatement : Text -> Text` — takes the 1-based index as text and returns a complete bind statement, e.g. `Codec.TEXT.bind(ps, 1, this.title().orElse(null));`.

- [ ] **Step 1: Add the two members to the Output type**

In `gen/Interpreters/Member.dhall`, in the `Output` record type, after the line `, needsCustomTypeImport : Bool`, add:

```dhall
      , decodeStatement : { rowVarPresent : Bool, colIdx : Text } -> Text
      , bindStatement : Text -> Text
```

- [ ] **Step 2: Add the two members to the combine record**

In the record returned by `combine` (inside `run`), after the `, needsCustomTypeImport = value.needsCustomTypeImport` line, add:

```dhall
                    , decodeStatement =
                        \(args : { rowVarPresent : Bool, colIdx : Text }) ->
                          let rowExpr =
                                if args.rowVarPresent then "row" else "0"

                          in  "${fieldType} ${fieldName}Col = ${value.mkDecodeExpr
                                                                  { isNullable =
                                                                      input.isNullable
                                                                  , rowExpr
                                                                  , colIdx =
                                                                      args.colIdx
                                                                  }};"
                    , bindStatement =
                        \(idx : Text) ->
                          "${value.codecRef}.bind(ps, ${idx}, ${value.mkBindValueExpr
                                                                  { isOptional
                                                                  , fieldAccess =
                                                                      "this.${fieldName}()"
                                                                  }});"
```

- [ ] **Step 3: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/Member.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`.

- [ ] **Step 4: Commit**

```bash
git add gen/Interpreters/Member.dhall
git commit -m "refactor: Member exposes ready-to-splice decode and bind statements"
```

---

### Task 4: ResultColumns consumes decodeStatement

**Files:**
- Modify: `gen/Interpreters/ResultColumns.dhall`

**Interfaces:**
- Consumes: `Member.Output.decodeStatement` from Task 3.
- Produces: unchanged `ResultColumns.Output`; `Templates/ColDecodeStatement.dhall` loses its only caller.

- [ ] **Step 1: Rewrite `mkDecodeLines`**

In `gen/Interpreters/ResultColumns.dhall`, replace the whole `mkDecodeLines` binding (the one that calls `Templates.ColDecodeStatement.run` with `colIdx`/`varName`/`fieldType`/`codecRef`/`dims`/`useOptional`/`isNullable`/`elementIsNullable`/`rowVarPresent`) with:

```dhall
                    let mkDecodeLines =
                          \(rowVarPresent : Bool) ->
                            Deps.Prelude.Text.concatMapSep
                              "\n"
                              { index : Natural, value : Member.Output }
                              ( \ ( ic
                                  : { index : Natural, value : Member.Output }
                                  ) ->
                                  ic.value.decodeStatement
                                    { rowVarPresent
                                    , colIdx = Natural/show (ic.index + 1)
                                    }
                              )
                              indexedColumns
```

- [ ] **Step 2: Remove the now-unused Templates import**

Delete this line from `gen/Interpreters/ResultColumns.dhall` (its only use was `ColDecodeStatement`):

```dhall
let Templates = ../Templates/package.dhall
```

- [ ] **Step 3: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/ResultColumns.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`.

- [ ] **Step 4: Commit**

```bash
git add gen/Interpreters/ResultColumns.dhall
git commit -m "refactor: ResultColumns consumes Member.decodeStatement"
```

---

### Task 5: Query consumes bindStatement

**Files:**
- Modify: `gen/Interpreters/Query.dhall` (the `paramBindCode` binding)

**Interfaces:**
- Consumes: `Member.Output.bindStatement` from Task 3.
- Produces: unchanged `Query.Output`; `Templates/ParamBindStatement.dhall` loses its only caller.

- [ ] **Step 1: Replace the ParamBindStatement call**

In `gen/Interpreters/Query.dhall`, inside `paramBindCode`, replace the `merge` branch:

```dhall
                                  { None = None Text
                                  , Some =
                                      \(p : Member.Output) ->
                                        Some
                                          ( Templates.ParamBindStatement.run
                                              { idx
                                              , fieldName = p.fieldName
                                              , codecRef = p.codecRef
                                              , isOptional = p.isOptional
                                              , elementIsOptional =
                                                  p.elementIsOptional
                                              , dims = p.dims
                                              }
                                          )
                                  }
```

with:

```dhall
                                  { None = None Text
                                  , Some =
                                      \(p : Member.Output) ->
                                        Some (p.bindStatement idx)
                                  }
```

- [ ] **Step 2: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/Query.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`.

- [ ] **Step 3: Commit**

```bash
git add gen/Interpreters/Query.dhall
git commit -m "refactor: Query consumes Member.bindStatement"
```

---

### Task 6: Delete the orphaned templates and prune Member's interface

**Files:**
- Delete: `gen/Templates/ColDecodeStatement.dhall`, `gen/Templates/ParamBindStatement.dhall`
- Modify: `gen/Templates/package.dhall` (remove two entries)
- Modify: `gen/Interpreters/Member.dhall` (remove `dims` and `elementIsNullable`)

**Interfaces:**
- Consumes: the rewired state from Tasks 4–5.
- Produces: `Member.Output` without `dims : Natural` and `elementIsNullable : Bool` — those facts are implementation now. Remaining consumers were verified: `Query` reads neither; `ResultColumns` reads neither after Task 4; `CustomType` reads `elementIsOptional`/`rawCodecType` (kept), not these.

- [ ] **Step 1: Delete the templates and their package entries**

```bash
git rm gen/Templates/ColDecodeStatement.dhall gen/Templates/ParamBindStatement.dhall
```

In `gen/Templates/package.dhall`, delete these two lines:

```dhall
, ParamBindStatement = ./ParamBindStatement.dhall
```

```dhall
, ColDecodeStatement = ./ColDecodeStatement.dhall
```

- [ ] **Step 2: Remove `dims` and `elementIsNullable` from Member**

In `gen/Interpreters/Member.dhall`:

Delete from the `Output` type:

```dhall
      , elementIsNullable : Bool
      , dims : Natural
```

Delete from the `combine` record:

```dhall
                    , elementIsNullable =
                        Deps.Prelude.Optional.fold
                          Model.ArraySettings
                          input.value.arraySettings
                          Bool
                          ( \(arr : Model.ArraySettings) ->
                              arr.elementIsNullable
                          )
                          False
                    , dims =
                        Deps.Prelude.Optional.fold
                          Model.ArraySettings
                          input.value.arraySettings
                          Natural
                          (\(arr : Model.ArraySettings) -> arr.dimensionality)
                          0
```

- [ ] **Step 3: Format, typecheck, golden diff**

```bash
dhall format gen/Templates/package.dhall gen/Interpreters/Member.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`. If typechecking fails on a missing field, a caller still reads `dims`/`elementIsNullable` — `grep -rn "\.dims\|elementIsNullable" gen` and fix that call site to stop consuming it before retrying.

- [ ] **Step 4: Commit**

```bash
git add -A gen
git commit -m "refactor: delete ColDecodeStatement and ParamBindStatement; shrink Member interface"
```

---

### Task 7: Full verification against the real build

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
