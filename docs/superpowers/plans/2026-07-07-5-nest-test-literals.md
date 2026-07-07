# Nest the Generated-Test Literals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Group the test-literal fields that ride every interpreter interface (`testDefaultLiteral`, `testRandomLiteral`, `testPresentLiteral`, `testAbsentLiteral`) into a single nested `test` sub-record, so each Output reads as "production surface + one test member".

**Architecture:** Literal generation for the *generated* integration tests is co-located with the type mapping in `Primitive.dhall` — that co-location is right, because the literal varies per PostgreSQL type. The friction is purely interface width: two flat `Text` fields ride `Primitive.Output` → `Scalar.Output` → `Value.Output`, and four ride `Member.Output`. This plan is a pure nesting rename: `Primitive`/`Scalar`/`Value` expose `test : { defaultLiteral : Text, randomLiteral : Text }`; `Member` exposes `test : { defaultLiteral : Text, randomLiteral : Text, presentLiteral : Text, absentLiteral : Text }`. Because the record types cascade through six files, the code change is one atomic task — intermediate states don't typecheck — followed by the end-to-end build.

**Tech Stack:** Dhall 1.42.3. Verification is `dhall type` on the whole tree plus a byte-for-byte golden diff of the generated demo output.

## Global Constraints

- **Prerequisites: plans 1 and 2 (`2026-07-07-1-…`, `2026-07-07-2-…`) must be fully applied** (this plan edits `Member.dhall` and the plan-2 version of `Value.dhall`). It is independent of plans 3 and 4 — the snippets below avoid the regions those plans touch.
- This is plan 5 of a 5-plan series.
- **Golden invariant:** generated output byte-identical to the baseline after every task. This refactor renames record fields only; no rendered `Text` changes.
- All commands run from the repo root. After editing any `.dhall` file: `dhall format <file>`.
- `demo-baseline/` and `demo-check/` are untracked scratch directories. Never commit them.
- Do not push. Commit per task with the messages given.

---

### Task 1: Capture the golden baseline

**Files:**
- Create: `demo-baseline/` (scratch, untracked)

**Interfaces:**
- Consumes: nothing.
- Produces: `demo-baseline/` for the golden diff:
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

### Task 2: Nest the literals through the whole chain (atomic)

**Files:**
- Modify: `gen/Interpreters/Primitive.dhall`
- Modify: `gen/Interpreters/Scalar.dhall`
- Modify: `gen/Interpreters/Value.dhall`
- Modify: `gen/Interpreters/Member.dhall`
- Modify: `gen/Interpreters/Query.dhall`
- Modify: `gen/Interpreters/CustomType.dhall`

**Interfaces:**
- Consumes: the post-plan-2 shapes of `Value.Output` and `Member.Output`.
- Produces:
  - `Primitive.Output`, `Scalar.Output`, `Value.Output`: flat `testDefaultLiteral : Text, testRandomLiteral : Text` replaced by `test : { defaultLiteral : Text, randomLiteral : Text }`.
  - `Member.Output`: flat `testDefaultLiteral, testRandomLiteral, testPresentLiteral, testAbsentLiteral` replaced by `test : { defaultLiteral : Text, randomLiteral : Text, presentLiteral : Text, absentLiteral : Text }`.
  - Consumers (`Query`, `CustomType`) read `m.test.defaultLiteral` etc.

Intermediate states do not typecheck at the tree level; per-file checks are used along the way and the whole-tree check runs at the end.

- [ ] **Step 1: Primitive — Output type**

In `gen/Interpreters/Primitive.dhall`, replace in `Output`:

```dhall
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
```

with:

```dhall
      , test : { defaultLiteral : Text, randomLiteral : Text }
```

- [ ] **Step 2: Primitive — the five literal producers**

Replace the `jdbcPrimitive` binding with:

```dhall
let jdbcPrimitive =
      \(javaType : Text) ->
      \(boxedJavaType : Text) ->
      \(codecName : Text) ->
      \(defaultLiteral : Text) ->
      \(randomLiteral : Text) ->
        Deps.Lude.Compiled.ok
          Output
          { javaType
          , boxedJavaType
          , codecRef = "Codec.${codecName}"
          , imports = noImports
          , test = { defaultLiteral, randomLiteral }
          }
```

Replace the `jdbcString` binding with:

```dhall
let jdbcString =
      \(codecName : Text) ->
        Deps.Lude.Compiled.ok
          Output
          { javaType = "String"
          , boxedJavaType = "String"
          , codecRef = "Codec.${codecName}"
          , imports = noImports
          , test =
              { defaultLiteral = "\"\""
              , randomLiteral = "java.util.UUID.randomUUID().toString()"
              }
          }
```

Replace the `dateType` binding with:

```dhall
let dateType =
      Deps.Lude.Compiled.ok
        Output
        { javaType = "LocalDate"
        , boxedJavaType = "LocalDate"
        , codecRef = "Codec.DATE"
        , imports = noImports
        , test =
            { defaultLiteral = "LocalDate.of(2000, 1, 1)"
            , randomLiteral =
                "Codec.DATE.toAgnostic().random(new java.util.Random(), 0)"
            }
        }
```

Replace the `codec` binding with:

```dhall
let codec =
      \(javaType : Text) ->
      \(codecName : Text) ->
      \(imports : ImportSet.Type) ->
        let codecRef = "Codec.${codecName}"

        in  Deps.Lude.Compiled.ok
              Output
              { javaType
              , boxedJavaType = javaType
              , codecRef
              , imports
              , test =
                  { defaultLiteral =
                      "${codecRef}.toAgnostic().random(new java.util.Random(0L), 0)"
                  , randomLiteral =
                      "${codecRef}.toAgnostic().random(new java.util.Random(), 0)"
                  }
              }
```

In the `Ltree` branch of the big `merge`, replace:

```dhall
                , testDefaultLiteral = "new Ltree(List.of(\"root\"))"
                , testRandomLiteral =
                    "new Ltree(List.of(java.util.UUID.randomUUID().toString()))"
```

with:

```dhall
                , test =
                    { defaultLiteral = "new Ltree(List.of(\"root\"))"
                    , randomLiteral =
                        "new Ltree(List.of(java.util.UUID.randomUUID().toString()))"
                    }
```

Then check this file in isolation:

```bash
dhall format gen/Interpreters/Primitive.dhall
dhall type --file gen/Interpreters/Primitive.dhall > /dev/null && echo OK
```

Expected: `OK`

- [ ] **Step 3: Scalar**

In `gen/Interpreters/Scalar.dhall`, in `Output`, replace:

```dhall
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
```

with:

```dhall
      , test : { defaultLiteral : Text, randomLiteral : Text }
```

The `Primitive` branch needs no edit — its `/\` record extension inherits the `test` member from `Primitive.Output`. In the `Custom` branch, replace:

```dhall
                      , testDefaultLiteral =
                          "${codecRef}.toAgnostic().random(new java.util.Random(0L), 0)"
                      , testRandomLiteral =
                          "${codecRef}.toAgnostic().random(new java.util.Random(), 0)"
```

with:

```dhall
                      , test =
                          { defaultLiteral =
                              "${codecRef}.toAgnostic().random(new java.util.Random(0L), 0)"
                          , randomLiteral =
                              "${codecRef}.toAgnostic().random(new java.util.Random(), 0)"
                          }
```

Then:

```bash
dhall format gen/Interpreters/Scalar.dhall
dhall type --file gen/Interpreters/Scalar.dhall > /dev/null && echo OK
```

Expected: `OK`

- [ ] **Step 4: Value**

In `gen/Interpreters/Value.dhall`, in `Output`, replace:

```dhall
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
```

with:

```dhall
      , test : { defaultLiteral : Text, randomLiteral : Text }
```

In the array branch (inside the `Optional.fold` over `arraySettings`), replace:

```dhall
                        , testDefaultLiteral = "List.of()"
                        , testRandomLiteral = "List.of()"
```

with:

```dhall
                        , test =
                            { defaultLiteral = "List.of()"
                            , randomLiteral = "List.of()"
                            }
```

In the scalar branch (the fold's default record), replace:

```dhall
                , testDefaultLiteral = scalar.testDefaultLiteral
                , testRandomLiteral = scalar.testRandomLiteral
```

with:

```dhall
                , test = scalar.test
```

Then:

```bash
dhall format gen/Interpreters/Value.dhall
dhall type --file gen/Interpreters/Value.dhall > /dev/null && echo OK
```

Expected: `OK`

- [ ] **Step 5: Member**

In `gen/Interpreters/Member.dhall`, in `Output`, replace:

```dhall
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
      , testPresentLiteral : Text
      , testAbsentLiteral : Text
```

with:

```dhall
      , test :
          { defaultLiteral : Text
          , randomLiteral : Text
          , presentLiteral : Text
          , absentLiteral : Text
          }
```

In the `combine` record, replace:

```dhall
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
```

with:

```dhall
                    , test =
                        { defaultLiteral =
                            if    isOptional
                            then  "Optional.empty()"
                            else  value.test.defaultLiteral
                        , randomLiteral =
                            if    isOptional
                            then  "Optional.of(${value.test.randomLiteral})"
                            else  value.test.randomLiteral
                        , presentLiteral =
                            if    isOptional
                            then  "Optional.of(${value.test.defaultLiteral})"
                            else  value.test.defaultLiteral
                        , absentLiteral =
                            if isOptional then "Optional.empty()" else "null"
                        }
```

Then:

```bash
dhall format gen/Interpreters/Member.dhall
dhall type --file gen/Interpreters/Member.dhall > /dev/null && echo OK
```

Expected: `OK`

- [ ] **Step 6: Query (consumer)**

In `gen/Interpreters/Query.dhall`, in the `defaultArgs` binding, replace:

```dhall
                (\(m : Member.Output) -> m.testDefaultLiteral)
```

with:

```dhall
                (\(m : Member.Output) -> m.test.defaultLiteral)
```

In the `testRandomArgs` binding, replace:

```dhall
                (\(m : Member.Output) -> m.testRandomLiteral)
```

with:

```dhall
                (\(m : Member.Output) -> m.test.randomLiteral)
```

- [ ] **Step 7: CustomType (consumer)**

In `gen/Interpreters/CustomType.dhall`, in the `fieldSpecs` mapping, replace:

```dhall
                                            { testPresentLiteral =
                                                m.testPresentLiteral
                                            , testAbsentLiteral =
                                                m.testAbsentLiteral
                                            , isVariable = m.isNullable
                                            }
```

with:

```dhall
                                            { testPresentLiteral =
                                                m.test.presentLiteral
                                            , testAbsentLiteral =
                                                m.test.absentLiteral
                                            , isVariable = m.isNullable
                                            }
```

(The local `FieldSpec` record and the combination logic below it keep their flat names — they are private to this module.)

- [ ] **Step 8: Whole-tree typecheck, golden diff**

```bash
dhall format gen/Interpreters/Query.dhall gen/Interpreters/CustomType.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
grep -rn "testDefaultLiteral\|testRandomLiteral" gen/Interpreters ; echo "grep-done"
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK`; the grep prints nothing before `grep-done`; then `IDENTICAL`.

- [ ] **Step 9: Commit**

```bash
git add gen/Interpreters
git commit -m "refactor: nest generated-test literals into a test sub-record"
```

---

### Task 3: Full verification against the real build

**Files:**
- Modify: `demo-output/` (regenerated, untracked)

**Interfaces:**
- Consumes: everything above.
- Produces: end-to-end proof — the generated library compiles and its Testcontainers suite (which consumes the literals this plan moved) passes.

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
