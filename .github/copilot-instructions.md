# java.gen

## Project Goal

This repository contains the pGenie generator for type-safe Java bindings over PostgreSQL.

The generated code should use JDBC plus the PostgreSQL codec library to provide strongly typed access to statements, result rows, scalar mappings, enums, and composite types.

## Source of Truth

Use these projects and references when making generator changes:

- pGenie documentation at https://pgenie.io/
- The reference Java generator design in https://github.com/pgenie-io/java.gen-design/
- The demo project in https://github.com/pgenie-io/demo/ for SQL of migrations and queries primarily
- The PostgreSQL codec library in https://github.com/codemine-io/postgresql-codecs.java/
- The generator SDK in https://github.com/pgenie-io/gen-sdk, especially the Dhall SDK under https://github.com/pgenie-io/gen-sdk/tree/master/dhall
- The existing Haskell generator in https://github.com/pgenie-io/haskell.gen/
- The existing Rust generator in https://github.com/pgenie-io/rust.gen/, which also generates tests

When the repository content conflicts with outside examples, prefer the structure and behavior established by java.gen-design.

## Dhall libs

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

## Working Expectations

- Make changes that preserve the structure and conventions already established in the repo.
- Keep the generated Java idiomatic and easy to read.
- Avoid introducing support for new shapes unless the codec library and reference generator behavior both justify it.
