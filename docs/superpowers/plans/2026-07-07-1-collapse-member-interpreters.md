# Collapse the Three Member Interpreters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `ParamsMember.dhall`, `ResultColumnsMember.dhall`, and `CustomTypeMember.dhall` with a single `Member.dhall` interpreter whose Output is the superset of all three, so the nullable-rendering rule exists in exactly one place.

**Architecture:** The three interpreters all perform the same Name ⊕ Value combine and each re-derive `isOptional`/`fieldType` from `config.useOptional`. The copies have drifted: for a nullable value without `useOptional`, `ResultColumnsMember.dhall:46` picks `value.javaType` (possibly a primitive like `int`) where `ParamsMember.dhall:49` picks `value.boxedJavaType`. The unified module standardises on `boxedJavaType` (the ParamsMember behaviour), which fixes a latent auto-unboxing NPE in generated result records. Callers keep their existing local alias names at first (one-line import-path change each), then aliases are renamed, then the three old files are deleted.

**Tech Stack:** Dhall 1.42.3. No test framework — verification is (a) `dhall type` on the whole tree via `tests/Exhaustive.dhall`, and (b) a golden diff: regenerate the demo output and compare it byte-for-byte to a baseline captured before any change.

## Global Constraints

- This is plan 1 of a 5-plan series (member collapse → value deepening → import centralisation → layout → test-literal nesting). It has no prerequisites.
- **Golden invariant:** the generated output must be byte-identical to the pre-refactor baseline after every task. The fixture runs with `useOptional = True`, so the drift fix (boxed vs primitive field type on the `useOptional = False` path) does not appear in the diff.
- All commands run from the repo root: `/Users/mojojojo/repos/pgenie/java.gen`.
- After editing any `.dhall` file, format it in place: `dhall format <file>`.
- `demo-baseline/` and `demo-check/` are scratch directories; the whitelist `.gitignore` already ignores them. Never commit them.
- Do not push. Commit per task with the messages given.

---

### Task 1: Capture the golden baseline

**Files:**
- Create: `demo-baseline/` (scratch, untracked)

**Interfaces:**
- Consumes: nothing.
- Produces: `demo-baseline/` — the reference output every later task diffs against. The check command used by all later tasks is:
  `rm -rf demo-check && dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check && diff -r demo-baseline demo-check`

- [ ] **Step 1: Confirm the working tree is clean**

Run: `git status --porcelain`
Expected: no output (only `docs/` plan files and `.gitignore` may appear if not yet committed; nothing under `gen/` or `tests/`).

- [ ] **Step 2: Generate the baseline**

```bash
rm -rf demo-baseline
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-baseline
```

Expected: exits 0 after ~20s.

- [ ] **Step 3: Verify the baseline is complete**

Run: `find demo-baseline -type f | wc -l`
Expected: `1093`

---

### Task 2: Create the unified Member interpreter

**Files:**
- Create: `gen/Interpreters/Member.dhall`

**Interfaces:**
- Consumes: `./Name.dhall` (`Name.Output = { fieldName : Text }`), `./Value.dhall` (`Value.Output` with `javaType`, `boxedJavaType`, `rawCodecType`, `elementIsOptional`, `codecRef`, `imports`, `pgCastSuffix`, `needsCustomTypeImport`, `testDefaultLiteral`, `testRandomLiteral`), `../Templates/package.dhall` (`ResultColumnField`), `../Algebras/Interpreter.dhall`.
- Produces: `Member.Output` and `Member.run : Algebra.Config -> Sdk.Project.Member -> Compiled Member.Output`. `Member.Output` is the field-superset of the three old interpreters' Outputs, with identical field names and identical semantics for every field (except `fieldType`, standardised on the ParamsMember rule). Tasks 3–5 point the three callers at this module.

- [ ] **Step 1: Write the new module**

Create `gen/Interpreters/Member.dhall` with exactly this content:

```dhall
let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Lude = Deps.Lude

let Model = Deps.Sdk.Project

let Templates = ../Templates/package.dhall

let Value = ./Value.dhall

let Name = ./Name.dhall

let Input = Model.Member

let Output =
      { fieldName : Text
      , fieldType : Text
      , pgName : Text
      , pgCastSuffix : Text
      , codecRef : Text
      , boxedJavaType : Text
      , rawCodecType : Text
      , columnField : Text
      , imports : ImportSet.Type
      , isNullable : Bool
      , isOptional : Bool
      , elementIsOptional : Bool
      , elementIsNullable : Bool
      , dims : Natural
      , needsCustomTypeImport : Bool
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
      , testPresentLiteral : Text
      , testAbsentLiteral : Text
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let combine =
              \(name : Name.Output) ->
              \(value : Value.Output) ->
                let fieldName = name.fieldName

                let isOptional = config.useOptional && input.isNullable

                let fieldType =
                      if    isOptional
                      then  "Optional<${value.boxedJavaType}>"
                      else  if input.isNullable
                      then  value.boxedJavaType
                      else  value.javaType

                in  { fieldName
                    , fieldType
                    , pgName = input.pgName
                    , pgCastSuffix = value.pgCastSuffix
                    , codecRef = value.codecRef
                    , boxedJavaType = value.boxedJavaType
                    , rawCodecType = value.rawCodecType
                    , columnField =
                        Templates.ResultColumnField.run
                          { pgName = input.pgName
                          , fieldType
                          , fieldName
                          , isNullable = input.isNullable
                          }
                    , imports = value.imports
                    , isNullable = input.isNullable
                    , isOptional
                    , elementIsOptional = value.elementIsOptional
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
                    , needsCustomTypeImport = value.needsCustomTypeImport
                    , testDefaultLiteral =
                        if    isOptional
                        then  "Optional.empty()"
                        else  value.testDefaultLiteral
                    , testRandomLiteral =
                        if    isOptional
                        then  "Optional.of(${value.testRandomLiteral})"
                        else  value.testRandomLiteral
                    , testPresentLiteral =
                        if    isOptional
                        then  "Optional.of(${value.testDefaultLiteral})"
                        else  value.testDefaultLiteral
                    , testAbsentLiteral =
                        if isOptional then "Optional.empty()" else "null"
                    }

        in  Lude.Compiled.map2
              Name.Output
              Value.Output
              Output
              combine
              ( Lude.Compiled.nest
                  Name.Output
                  input.pgName
                  (Name.run config input.name)
              )
              ( Lude.Compiled.nest
                  Value.Output
                  input.pgName
                  (Value.run config input.value)
              )

in  Algebra.module Input Output run
```

Semantics carried over, for review: `fieldType` and `testDefaultLiteral`/`testRandomLiteral` reproduce `ParamsMember.dhall:44-79`; `columnField`, `elementIsNullable`, `dims` reproduce `ResultColumnsMember.dhall:42-79`; `testPresentLiteral`/`testAbsentLiteral` reproduce `CustomTypeMember.dhall:51-57`. The single deliberate change: result columns now get `boxedJavaType` (not `javaType`) when nullable and `useOptional = False`.

- [ ] **Step 2: Format and typecheck the new module**

```bash
dhall format gen/Interpreters/Member.dhall
dhall type --file gen/Interpreters/Member.dhall > /dev/null && echo OK
```

Expected: `OK`

- [ ] **Step 3: Verify golden output is unchanged (module not yet wired in — sanity check the harness)**

```bash
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `IDENTICAL`

- [ ] **Step 4: Commit**

```bash
git add gen/Interpreters/Member.dhall
git commit -m "refactor: add unified Member interpreter (superset of the three member interpreters)"
```

---

### Task 3: Point Query at Member

**Files:**
- Modify: `gen/Interpreters/Query.dhall:19` (the `ParamsMemberModule` import)

**Interfaces:**
- Consumes: `Member.Output` from Task 2. Every field Query reads (`pgCastSuffix`, `fieldName`, `codecRef`, `isOptional`, `elementIsOptional`, `dims`, `imports`, `pgName`, `fieldType`, `isNullable`, `needsCustomTypeImport`, `testDefaultLiteral`, `testRandomLiteral`) exists on `Member.Output` with the same name and type.
- Produces: `Query.dhall` compiled against the unified module. The alias name `ParamsMemberModule` is kept in this task (renamed in Task 6).

- [ ] **Step 1: Change the import path**

In `gen/Interpreters/Query.dhall`, replace:

```dhall
let ParamsMemberModule = ./ParamsMember.dhall
```

with:

```dhall
let ParamsMemberModule = ./Member.dhall
```

- [ ] **Step 2: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/Query.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`

- [ ] **Step 3: Commit**

```bash
git add gen/Interpreters/Query.dhall
git commit -m "refactor: Query consumes the unified Member interpreter"
```

---

### Task 4: Point ResultColumns at Member

**Files:**
- Modify: `gen/Interpreters/ResultColumns.dhall:7` (the `ResultColumnsMember` import)

**Interfaces:**
- Consumes: `Member.Output` from Task 2 (fields read here: `columnField`, `fieldName`, `fieldType`, `codecRef`, `dims`, `isNullable`, `elementIsNullable`, `imports`, `needsCustomTypeImport`).
- Produces: `ResultColumns.dhall` compiled against the unified module, alias kept.

- [ ] **Step 1: Change the import path**

In `gen/Interpreters/ResultColumns.dhall`, replace:

```dhall
let ResultColumnsMember = ./ResultColumnsMember.dhall
```

with:

```dhall
let ResultColumnsMember = ./Member.dhall
```

- [ ] **Step 2: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/ResultColumns.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`. Note: the golden output is identical despite the fieldType unification because the fixture runs `useOptional = True`, where all three modules already agreed.

- [ ] **Step 3: Commit**

```bash
git add gen/Interpreters/ResultColumns.dhall
git commit -m "refactor: ResultColumns consumes the unified Member interpreter (fixes boxed-type drift)"
```

---

### Task 5: Point CustomType at Member

**Files:**
- Modify: `gen/Interpreters/CustomType.dhall:15` (the `MemberGen` import)

**Interfaces:**
- Consumes: `Member.Output` from Task 2 (fields read here: `pgName`, `fieldName`, `fieldType`, `rawCodecType`, `elementIsOptional`, `codecRef`, `isOptional`, `isNullable`, `imports`, `testPresentLiteral`, `testAbsentLiteral`).
- Produces: `CustomType.dhall` compiled against the unified module, alias kept.

- [ ] **Step 1: Change the import path**

In `gen/Interpreters/CustomType.dhall`, replace:

```dhall
let MemberGen = ./CustomTypeMember.dhall
```

with:

```dhall
let MemberGen = ./Member.dhall
```

- [ ] **Step 2: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/CustomType.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`

- [ ] **Step 3: Commit**

```bash
git add gen/Interpreters/CustomType.dhall
git commit -m "refactor: CustomType consumes the unified Member interpreter"
```

---

### Task 6: Rename the stale aliases and delete the three old interpreters

**Files:**
- Modify: `gen/Interpreters/Query.dhall` (alias `ParamsMemberModule` → `Member`, 11 occurrences)
- Modify: `gen/Interpreters/ResultColumns.dhall` (alias `ResultColumnsMember` → `Member`, ~12 occurrences)
- Modify: `gen/Interpreters/CustomType.dhall` (alias `MemberGen` → `Member`, ~6 occurrences)
- Delete: `gen/Interpreters/ParamsMember.dhall`, `gen/Interpreters/ResultColumnsMember.dhall`, `gen/Interpreters/CustomTypeMember.dhall`

**Interfaces:**
- Consumes: the wired-up state from Tasks 3–5.
- Produces: the final module layout. Later plans (value deepening, import centralisation, test-literal nesting) refer to the member interpreter as `Member` and to callers' alias as `Member` — this task establishes those names.

- [ ] **Step 1: Rename the aliases mechanically**

```bash
sed -i '' 's/ParamsMemberModule/Member/g' gen/Interpreters/Query.dhall
sed -i '' 's/ResultColumnsMember/Member/g' gen/Interpreters/ResultColumns.dhall
sed -i '' 's/MemberGen/Member/g' gen/Interpreters/CustomType.dhall
```

- [ ] **Step 2: Delete the superseded interpreters**

```bash
git rm gen/Interpreters/ParamsMember.dhall gen/Interpreters/ResultColumnsMember.dhall gen/Interpreters/CustomTypeMember.dhall
```

- [ ] **Step 3: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/Query.dhall gen/Interpreters/ResultColumns.dhall gen/Interpreters/CustomType.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`. If `dhall type` fails with a missing-import error, something still references a deleted file — `grep -rn "ParamsMember\|ResultColumnsMember\|CustomTypeMember" gen tests` must come back empty.

- [ ] **Step 4: Commit**

```bash
git add -A gen/Interpreters
git commit -m "refactor: delete the three superseded member interpreters"
```

---

### Task 7: Full verification against the real build

**Files:**
- Modify: `demo-output/` (regenerated, untracked)

**Interfaces:**
- Consumes: everything above.
- Produces: a demo library that compiles and passes its Testcontainers integration suite — proof the refactor preserved behaviour end-to-end.

- [ ] **Step 1: Regenerate the checked-in demo output location**

```bash
rm -rf demo-output
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-output
```

Expected: exits 0.

- [ ] **Step 2: Build and run the generated integration tests (requires Docker running, ~minutes)**

```bash
cd demo-output && mvn -q verify && cd -
```

Expected: `BUILD SUCCESS`.

- [ ] **Step 3: Clean up scratch directories**

```bash
rm -rf demo-baseline demo-check
```
