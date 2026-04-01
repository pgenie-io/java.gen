# java.gen

A [pGenie](https://github.com/pgenie-io/pgenie) plugin that generates type-safe Java
bindings for PostgreSQL based on JDBC with support for most of the PostgreSQL data
types including arrays, composites and multiranges.

## What it generates

For each pGenie project the plugin produces a self-contained Maven library containing:

- **`pom.xml`** – a ready-to-build library declaring all required runtime dependencies.
- **`src/main/java/<namespace>/Statement.java`** – a shared interface implemented by every
  generated statement class. Provides a uniform `execute(Connection)` method that
  handles preparing, binding, executing, and decoding.
- **`src/main/java/<namespace>/codecs/Jdbc.java`** – a thin bridge utility that encodes
  values via `postgresql-codecs` `Codec<A>` instances into `PGobject` for pgjdbc.
- **`src/main/java/<namespace>/statements/*.java`** – one record class per SQL query.
  Each class contains:
  - A constructor parameter per query parameter (javadoc-annotated with the SQL
    placeholder name).
  - An `Output` record type (or `Long` for non-returning statements) as the result.
  - A full `Statement<Output>` implementation holding the SQL text, parameter binding
    logic, and result-set decoding logic.
- **`src/main/java/<namespace>/types/*.java`** – one class per custom PostgreSQL type:
  - **Enums** → Java `enum` declarations with an `EnumCodec` constant.
  - **Composite types** → Java `record` declarations with a `CompositeCodec` constant.
- **`src/test/java/<namespace>/statements/*IT.java`** – one integration test per
  statement. Tests spin up a throwaway PostgreSQL container via
  [Testcontainers](https://testcontainers.com/) and run migrations from the pGenie
  project before executing each statement.

## Using the plugin in a pGenie project

Add the plugin to your pGenie project configuration file (`project1.pgn.yaml`):

```yaml
space: my_space
name: music_catalogue
version: 1.0.0
artifacts:
  java:
    https://raw.githubusercontent.com/pgenie-io/java.gen/master/gen/Gen.dhall
```

Run the code generator:

```bash
pgenie generate
```

The generated library will be placed in `artifacts/java/` as configured in your
project.

## Supported PostgreSQL types

Scalar types can appear as plain values, as nullable values
(`@Nullable T` semantics — `null` in Java), or as arrays of any dimensionality
(`List<T>`, `List<List<T>>`, …) with controllable element nullability.

| PostgreSQL type | Java type | Notes |
|---|---|---|
| `bool` | `boolean` / `Boolean` | JDBC primitive |
| `int2` / `smallint` | `short` / `Short` | JDBC primitive |
| `int4` / `integer` | `int` / `Integer` | JDBC primitive |
| `int8` / `bigint` | `long` / `Long` | JDBC primitive |
| `float4` / `real` | `float` / `Float` | JDBC primitive |
| `float8` / `double precision` | `double` / `Double` | JDBC primitive |
| `text` | `String` | JDBC string |
| `varchar` | `String` | JDBC string |
| `bpchar` / `char(n)` | `String` | JDBC string |
| `name` | `String` | JDBC string |
| `citext` | `String` | postgresql-codecs |
| `date` | `LocalDate` | via `java.sql.Date.valueOf()` |
| `time` | `LocalTime` | postgresql-codecs |
| `timestamp` | `LocalDateTime` | postgresql-codecs |
| `timestamptz` | `Instant` | postgresql-codecs |
| `timetz` | `Timetz` | postgresql-codecs |
| `numeric` | `BigDecimal` | postgresql-codecs |
| `uuid` | `UUID` | postgresql-codecs |
| `bytea` | `Bytea` | postgresql-codecs |
| `oid` | `Integer` | postgresql-codecs |
| `money` | `Long` | postgresql-codecs |
| `json` | `JsonNode` | postgresql-codecs (jackson) |
| `jsonb` | `JsonNode` | postgresql-codecs (jackson) |
| `bit` | `Bit` | postgresql-codecs |
| `varbit` | `Bit` | postgresql-codecs |
| `"char"` | `Byte` | postgresql-codecs |
| `inet` | `Inet` | postgresql-codecs |
| `cidr` | `Cidr` | postgresql-codecs |
| `macaddr` | `Macaddr` | postgresql-codecs |
| `macaddr8` | `Macaddr8` | postgresql-codecs |
| `interval` | `Interval` | postgresql-codecs |
| `tsvector` | `Tsvector` | postgresql-codecs |
| `hstore` | `Hstore` | postgresql-codecs |
| `point` | `Point` | postgresql-codecs |
| `line` | `Line` | postgresql-codecs |
| `lseg` | `Lseg` | postgresql-codecs |
| `box` | `Box` | postgresql-codecs |
| `path` | `Path` | postgresql-codecs |
| `polygon` | `Polygon` | postgresql-codecs |
| `circle` | `Circle` | postgresql-codecs |
| `int4range` | `Range<Integer>` | postgresql-codecs |
| `int8range` | `Range<Long>` | postgresql-codecs |
| `numrange` | `Range<BigDecimal>` | postgresql-codecs |
| `tsrange` | `Range<LocalDateTime>` | postgresql-codecs |
| `tstzrange` | `Range<Instant>` | postgresql-codecs |
| `daterange` | `Range<LocalDate>` | postgresql-codecs |
| `int4multirange` | `Multirange<Integer>` | postgresql-codecs |
| `int8multirange` | `Multirange<Long>` | postgresql-codecs |
| `nummultirange` | `Multirange<BigDecimal>` | postgresql-codecs |
| `tsmultirange` | `Multirange<LocalDateTime>` | postgresql-codecs |
| `tstzmultirange` | `Multirange<Instant>` | postgresql-codecs |
| `datemultirange` | `Multirange<LocalDate>` | postgresql-codecs |

Types labeled **postgresql-codecs** use the
[`postgresql-codecs`](https://github.com/codemine-io/postgresql-codecs.java) library for
their Java representation and are sent to pgjdbc as text-format `PGobject` values via
the generated `Jdbc` helper.

### Unsupported types

The following PostgreSQL types are not supported by this generator. Statements using
these types produce warnings during code generation and are skipped entirely.

| PostgreSQL type | Reason |
|---|---|
| `pg_lsn` | No codec available in postgresql-codecs |
| `pg_snapshot` | No codec available in postgresql-codecs |
| `tsquery` | No codec available in postgresql-codecs |
| `xml` | No codec available in postgresql-codecs |

### Notes

- **Nullable types**: when a column or parameter is nullable, the Java type uses the
  boxed form (e.g. `Integer` instead of `int`). `null` is passed and returned directly.
- **Array types**: PostgreSQL arrays map to `List<T>` (one-dimensional) or nested
  `List<List<T>>` for multi-dimensional arrays. Element nullability uses the boxed type.
- **Custom enum types**: user-defined PostgreSQL enums generate a Java `enum` with an
  `EnumCodec` constant (`MY_ENUM.CODEC`) for use in composite and array contexts.
- **Custom composite types**: user-defined PostgreSQL composite types generate a Java
  `record` with a `CompositeCodec` constant. Composites that contain unsupported field
  types are skipped along with any statements referencing them.
- **Domain types**: not supported by this generator.

## Using the generated code

The generated library is designed to be used from application code or integration
tests. Each statement is a Java record whose constructor accepts the query parameters.
Call `.execute(conn)` with a JDBC `Connection` to run the statement.

```java
import io.pgenie.artifacts.my_space.music_catalogue.statements.InsertAlbum;
import io.pgenie.artifacts.my_space.music_catalogue.types.AlbumFormat;
import io.pgenie.artifacts.my_space.music_catalogue.types.RecordingInfo;

import java.sql.Connection;
import java.time.LocalDate;

void example(Connection conn) throws SQLException {
    // Execute an insert that returns the new row id.
    var result = new InsertAlbum(
        "Space Jazz Vol. 1",
        LocalDate.of(2020, 5, 4),
        AlbumFormat.Vinyl,
        new RecordingInfo(
            "Galactic Studio",
            "Lunar City",
            "Moon",
            LocalDate.of(2019, 12, 1)
        )
    ).execute(conn);
    System.out.println("Inserted album id=" + result.id());

    // Query rows back by name.
    var rows = new SelectAlbumByName("Space Jazz Vol. 1").execute(conn);
    for (var row : rows) {
        System.out.println("Found album id=" + row.id() + " name=" + row.name());
    }
}
```

## Building

The generator is written in [Dhall](https://dhall-lang.org/).
Install Dhall by following the instructions at
https://docs.dhall-lang.org/tutorials/Getting-started_Generate-JSON-or-YAML.html.

To check the generator against the demo fixture:

```bash
dhall --file gen/demo.dhall
```

