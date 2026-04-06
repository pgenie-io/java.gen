# v0.3.0

## Breaking changes

- Renamed generated result classes: the generated `Output` and `OutputRow` classes were renamed to `Result` and `ResultRow` respectively for better clarity.
- Migrated to the `io.codemine.java.postgresql:jdbc` library for the `Codec` and `Statement` abstractions.

# v0.2.0

## Breaking changes

- Replaced JDBC helper class and package: the previous `io.pgenie.artifacts.*.codecs.Jdbc` utility was removed and replaced by a new generic class `io.pgenie.artifacts.*.JdbcCodec<A>`. Call sites must update imports and adapt to the new API: `JdbcCodec.bind(PreparedStatement, int, A)` and decode methods (`decodeNullable` / `decodeNonNullable`) that now throw `SQLException` with SQLState codes on decode errors.

### Notes / migration hints

- Update imports from the old codecs package to the new `JdbcCodec` class and adapt calls to the new method names and signatures.
- Handle `SQLExceptions` thrown by decode methods; these now surface decoding failures with SQLState codes (22000 for decode failures, 22004 for unexpected NULLs).
- If switching to Optional-based generation, update caller code to unwrap `Optional<T>` (or use `.orElse` / `.orElseThrow` as appropriate).

## Non-breaking / additive

- Nullability handling (Optional support): the generator adds templates to emit `Optional<T>` for nullable parameters/fields when the generator option `useOptional` is enabled. If your code relied on nullable references produced by the older generator, switching to `useOptional` will be an API-breaking change.
