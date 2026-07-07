# Package Layout Computed Once Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Derive the Java package name, source/test path prefixes, Maven groupId, and artifactId in exactly one place (`compile.dhall`), pass them through the existing `Algebra.Config` seam, and delete both the re-derivation in `Project.dhall` and the dead `rootModuleName` config field.

**Architecture:** Today `compile.dhall:22-28` builds `packageName` (`io.pgenie.artifacts.<space><name>` with underscores stripped) and `Project.dhall:21-38` rebuilds the same fact independently via its own `toFlatLower`, along with `srcPrefix`/`testPrefix`/`groupId`. If the layout scheme changes in one file, generated files land in paths that no longer match their `package` declarations. Meanwhile `Config.rootModuleName` is set in `compile.dhall` and read nowhere. The fix widens the internal `Config` record — the seam every interpreter already receives — and makes `Project.dhall` a pure consumer.

**Tech Stack:** Dhall 1.42.3. Verification is `dhall type` on the whole tree plus a byte-for-byte golden diff of the generated demo output.

## Global Constraints

- **Prerequisites: none.** This plan touches only `gen/Algebras/Interpreter.dhall`, `gen/compile.dhall`, and `gen/Interpreters/Project.dhall`, which plans 1–3 and 5 do not modify. It can be applied at any point in the series.
- This is plan 4 of a 5-plan series.
- **Golden invariant:** generated output byte-identical to the baseline after every task.
- The plugin's *external* config schema (`gen/Config.dhall`, `{ useOptional : Bool }`) must not change — it is the published interface consumed by pGenie project files. Only the *internal* `Algebras/Interpreter.dhall` `Config` changes.
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

### Task 2: Widen the internal Config and compute the layout in compile.dhall

**Files:**
- Modify: `gen/Algebras/Interpreter.dhall` (the `Config` type)
- Modify: `gen/compile.dhall` (full replacement below)

**Interfaces:**
- Consumes: `Sdk.Project.Name` (provides `inSnakeCase`, `inKebabCase`), `Prelude.Text.replace`.
- Produces: the new internal seam every interpreter receives:
  `Config = { packageName : Text, srcPrefix : Text, testPrefix : Text, groupId : Text, artifactId : Text, useOptional : Bool }`.
  `rootModuleName` is gone (it was set once and read nowhere — verify with the grep in Step 3). Task 3 makes `Project.dhall` consume the new fields.

- [ ] **Step 1: Change the Config type**

In `gen/Algebras/Interpreter.dhall`, replace:

```dhall
let Config = { rootModuleName : Text, packageName : Text, useOptional : Bool }
```

with:

```dhall
let Config =
      { packageName : Text
      , srcPrefix : Text
      , testPrefix : Text
      , groupId : Text
      , artifactId : Text
      , useOptional : Bool
      }
```

- [ ] **Step 2: Replace `gen/compile.dhall` with this content**

```dhall
let Deps = ./Deps/package.dhall

let Sdk = Deps.Sdk

let Config = ./Config.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

in  \(config : Optional Config) ->
    \(project : Sdk.Project.Project) ->
      let useOptional =
            Deps.Prelude.Optional.fold
              Config
              config
              Bool
              (\(c : Config) -> c.useOptional)
              False

      let flatten =
            \(name : Sdk.Project.Name) ->
              Deps.Prelude.Text.replace "_" "" name.inSnakeCase

      let spacePkg = flatten project.space

      let namePkg = flatten project.name

      let interpreterConfig =
            { packageName = "io.pgenie.artifacts.${spacePkg}.${namePkg}"
            , srcPrefix =
                "src/main/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"
            , testPrefix =
                "src/test/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"
            , groupId = "io.pgenie.artifacts.${spacePkg}"
            , artifactId = project.name.inKebabCase
            , useOptional
            }

      in  ProjectInterpreter.run interpreterConfig project
```

- [ ] **Step 3: Confirm `rootModuleName` was genuinely dead**

Run: `grep -rn "rootModuleName" gen tests`
Expected: no output. (If anything appears, stop — that consumer must be migrated first.)

- [ ] **Step 4: Format, typecheck, golden diff**

```bash
dhall format gen/Algebras/Interpreter.dhall gen/compile.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL` (`Project.dhall` still recomputes its own values at this point; the new config fields are simply unread).

- [ ] **Step 5: Commit**

```bash
git add gen/Algebras/Interpreter.dhall gen/compile.dhall
git commit -m "refactor: compute package layout once in compile.dhall; drop dead rootModuleName"
```

---

### Task 3: Project consumes the layout from Config

**Files:**
- Modify: `gen/Interpreters/Project.dhall`

**Interfaces:**
- Consumes: `config.packageName`, `config.srcPrefix`, `config.testPrefix`, `config.groupId`, `config.artifactId` from Task 2.
- Produces: `Project.dhall` with zero layout derivation. `combineOutputs` gains `config : Algebra.Config` as its first parameter. `projectName`, `version`, and `dbName` stay input-derived — they are display/database names, not layout.

- [ ] **Step 1: Delete the re-derivation**

In `gen/Interpreters/Project.dhall`:

Delete the top-level helper:

```dhall
let toFlatLower =
      \(name : Model.Name) -> Deps.Prelude.Text.replace "_" "" name.inSnakeCase
```

Change the `combineOutputs` head from:

```dhall
let combineOutputs =
      \(input : Input) ->
      \(queries : List QueryGen.Output) ->
      \(customTypes : List CustomTypeGen.Output) ->
```

to:

```dhall
let combineOutputs =
      \(config : Algebra.Config) ->
      \(input : Input) ->
      \(queries : List QueryGen.Output) ->
      \(customTypes : List CustomTypeGen.Output) ->
```

Delete these five bindings from the body of `combineOutputs`:

```dhall
        let spacePkg = toFlatLower input.space

        let namePkg = toFlatLower input.name

        let packageName = "io.pgenie.artifacts.${spacePkg}.${namePkg}"

        let srcPrefix =
              "src/main/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"

        let testPrefix =
              "src/test/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"
```

and this one:

```dhall
        let artifactId = input.name.inKebabCase
```

- [ ] **Step 2: Reroute every use to config**

Still in `gen/Interpreters/Project.dhall`, apply these substitutions in the body of `combineOutputs`:

- `srcPrefix ++ "types/" ++ customType.modulePath` → `config.srcPrefix ++ "types/" ++ customType.modulePath`
- `testPrefix ++ "types/" ++ customType.testModulePath` → `config.testPrefix ++ "types/" ++ customType.testModulePath`
- `srcPrefix ++ "statements/" ++ query.statementModulePath` → `config.srcPrefix ++ "statements/" ++ query.statementModulePath`
- `testPrefix ++ "statements/" ++ query.testModulePath` → `config.testPrefix ++ "statements/" ++ query.testModulePath`
- In `abstractDatabaseIT`: `path = testPrefix ++ "AbstractDatabaseIT.java"` → `path = config.testPrefix ++ "AbstractDatabaseIT.java"`, and `Templates.AbstractDatabaseIT.run { packageName, migrations }` → `Templates.AbstractDatabaseIT.run { packageName = config.packageName, migrations }`
- In the `readmeMd` argument record: `groupId = "io.pgenie.artifacts.${spacePkg}"` → `groupId = config.groupId`, `artifactId` → `artifactId = config.artifactId`, `packageName` → `packageName = config.packageName`
- In the `pomXml` argument record: `groupId = "io.pgenie.artifacts.${spacePkg}"` → `groupId = config.groupId`, `artifactId` → `artifactId = config.artifactId`

Finally, in `run`, change the call:

```dhall
                (combineOutputs input)
```

to:

```dhall
                (combineOutputs config input)
```

- [ ] **Step 3: Confirm no derivation remains**

Run: `grep -n "io.pgenie.artifacts\|toFlatLower\|spacePkg\|namePkg" gen/Interpreters/Project.dhall`
Expected: no output — the string `io.pgenie.artifacts` now exists only in `gen/compile.dhall`.

- [ ] **Step 4: Format, typecheck, golden diff**

```bash
dhall format gen/Interpreters/Project.dhall
dhall type --file tests/Exhaustive.dhall > /dev/null && echo TYPES-OK
rm -rf demo-check
dhall to-directory-tree --allow-path-separators --file tests/Exhaustive.dhall --output demo-check
diff -r demo-baseline demo-check && echo IDENTICAL
```

Expected: `TYPES-OK` then `IDENTICAL`.

- [ ] **Step 5: Commit**

```bash
git add gen/Interpreters/Project.dhall
git commit -m "refactor: Project consumes package layout from Config instead of recomputing it"
```

---

### Task 4: Full verification against the real build

**Files:**
- Modify: `demo-output/` (regenerated, untracked)

**Interfaces:**
- Consumes: everything above.
- Produces: end-to-end proof — the generated library compiles and its Testcontainers suite passes. This exercises the path/package agreement directly: a mismatch between `srcPrefix` and `packageName` fails `mvn` compilation immediately.

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
