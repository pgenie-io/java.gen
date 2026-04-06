# java.gen

## Project Goal

This repository contains the pGenie generator for type-safe Java bindings over PostgreSQL.

The generated code should use JDBC plus the PostgreSQL codec library to provide strongly typed access to statements, result rows, scalar mappings, enums, and composite types.

## Source of Truth

Use these projects and references when making generator changes:

- pGenie documentation at https://pgenie.io/
- The demo project in https://github.com/pgenie-io/demo/ for SQL of migrations and queries primarily. Ignore the `artifacts` in it, as they are only meant to be the output of the generator and not a reference for how the generator should work. The SQL in the migrations and queries is the main reference for how the input SQL should be structured and what features it uses.
- The PostgreSQL JDBC bridge library in https://github.com/codemine-io/postgresql-jdbc.java/. It is the main reference for how to use the codec library and what features it supports. Pay attention to the supported PostgreSQL types and Java type mappings, as well as how to set up the Maven dependencies.
- The generator SDK in https://github.com/pgenie-io/gen-sdk, especially the Dhall SDK under https://github.com/pgenie-io/gen-sdk/tree/master/dhall
- The existing Haskell generator in https://github.com/pgenie-io/haskell.gen/
- The existing Rust generator in https://github.com/pgenie-io/rust.gen/, which also generates tests

When the repository content conflicts with outside examples, prefer the structure and behavior established by java.gen-design.

## Dhall libs

- [Prelude](https://store.dhall-lang.org/Prelude-v23.1.0/index.html) - the standard Dhall Prelude library, for basic utilities and data structures. Load that into memory! This is your bread and butter for working with Dhall.
- https://github.com/codemine-io/lude.dhall - utils
  - E.g., `Lude.Extensions.Text.indent` - a utility for indenting multiline strings, which is very useful for generating code with correct indentation.
    - Use it instead of manually adding indentation in strings!
- https://github.com/nikita-volkov/typeclasses.dhall - library of Haskell-inspired typeclasses and general utilities base on them.
- https://github.com/codemine-io/codegen-kit.dhall - utilities for code generation.

## Generator Structure

- Do not pay attention to `demo-output/` in this repo or in the Haskell and Rust reference generators. It is only intended to be the result of running the generator.
- Target Java 21.
- Keep the Maven output compatible with Java 21 build setup.
- Keep the Maven set up idiomatic, simple and up to date with the latest releases.
- Extract templates producing strings into `gen/Templates/`. Avoid inlining them in `gen/Interpreters/` as much as possible.

### Interpreters

The interpeters should be structured as a tree resembling structured after the input model. The outer layers compose the outputs from the inner layers and collapse the data structures by evaluating the templates once the data is available.

The purpose of the Output data structure is to contain all uses of the input data structure for evaluating templates.

The Output types should not be declared as functions with extra parameters. That would signal that the interpreter is overstretching and trying to reach a context outside of its scope. Instead, it should just export the building blocks for what the calling interpreter (outer context) may need from it. At the same time, the interpreter should always strive to simplify (collapse) the output structure by evaluating the templates as soon as the data is available.

## Type Mapping Rules

- Derive PostgreSQL-to-Java type mapping from the PostgreSQL codec library.
- Prefer pgjdbc standard methods wherever they are available.
- Keep statement parameter binding and result decoding type-safe.
- Follow the existing statement and composite type patterns in the generated demo project.

## Unsupported Type Handling

- If a statement uses an unsupported PostgreSQL type, emit a warning and skip generating that statement.
- If a composite type contains an unsupported field type, treat the composite as unsupported.
- Skip any statements that depend on unsupported composite types.
- Do not silently generate partial bindings for unsupported inputs.

## Design rules

- `gen/Templates/` must not depend on `gen/Interpreters/` or the Project model from `Deps.Sdk`.
- Textual templates should be extracted into `gen/Templates/` as much as possible. `gen/Interpreters/` should primarily be responsible for interpreting the Project model and orchestrating the generation process.
- Templates may depend on other templates and their parameter structures may contain parameter structures of other templates. This may be especially useful for lists and optionals.
  - However a final design decision has not been made on this and it may be simpler to just have the templates be simple and independent, with the interpreters responsible for composing them together as needed by calling them and thus interpreting into structures over chunks of text.
    - Pick either approach, just be consistent within the boundaries of a module.

## Dhall Code Style Rules

### No pointless string concatenations

Never concatenate two string literals with `++` when they can be a single literal. A `"\n"` between two multiline strings, or a short literal like `" */"` after a multiline string, must be absorbed into the adjacent string.

Bad: `'' ... '' ++ " */"` or `someStr ++ "\n" ++ '' ... ''`
Good: fold the literal into the neighbouring multiline string.

### Prefer interpolation over concatenation

When embedding a variable in a string, use Dhall string interpolation (`${expr}`) instead of `"prefix" ++ expr ++ "suffix"`.

Bad: `"Optional<" ++ boxedType ++ ">"`
Good: `"Optional<${boxedType}>"`

### Indentation via `indent`, never manual

Never embed indentation in generated string fragments using `${"    "}` padding or hardcoded leading spaces. Instead, produce the string content without indentation and apply `Deps.Lude.Extensions.Text.indent` at the splice site.

Bad (in fragment builder):
```dhall
''
${"        "}/**
${"        "} * Doc.
${"        "} */
${"        "}${fieldType} ${fieldName}''
```

Good (fragment builder produces unindented content, splice site indents):
```dhall
-- builder:
''
/**
 * Doc.
 */
${fieldType} ${fieldName}''

-- splice site:
Deps.Lude.Extensions.Text.indent 8 fragment
```

### Indentation belongs at the splice site, not the construction site

Any string that is meant to be spliced into another string must be constructed without indentation. The `Deps.Lude.Extensions.Text.indent` utility must be applied where the string is spliced into its surrounding context. This eliminates coupling between the string builder and the indentation level of the context it lands in.

### Import lists via list operations, not per-import conditionals

Instead of declaring individual `let importFoo = if cond then "import ..." else ""` variables and concatenating them, collect imports into a `List Text` using conditional list append or filter, then join them with `Deps.Prelude.Text.concatSep "\n"`. Group imports into sections (e.g., `java.sql.*`, `java.util.*`) with a blank line between groups.

## Working Expectations

- Make changes that preserve the structure and conventions already established in the repo.
- Keep the generated Java idiomatic and easy to read.
- Avoid introducing support for new shapes unless the codec library and reference generator behavior both justify it.
