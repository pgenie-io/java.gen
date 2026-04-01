let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Templates = ../Templates/package.dhall

let QueryGen = ./Query.dhall

let CustomTypeGen = ./CustomType.dhall

let Input = Model.Project

let Output = List Sdk.File.Type

let toFlatLower =
      \(name : Model.Name) ->
        Deps.Prelude.Text.replace
          "_"
          ""
          (Deps.CodegenKit.Name.toTextInSnake name)

let combineOutputs =
      \(config : Algebra.Config) ->
      \(input : Input) ->
      \(queries : List QueryGen.Output) ->
      \(customTypes : List CustomTypeGen.Output) ->
        let spacePkg = toFlatLower input.space

        let namePkg = toFlatLower input.name

        let packageName = "io.pgenie.artifacts.${spacePkg}.${namePkg}"

        let srcPrefix =
              "src/main/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"

        let testPrefix =
              "src/test/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"

        let customTypeFiles
            : List Sdk.File.Type
            = Deps.Prelude.List.map
                CustomTypeGen.Output
                Sdk.File.Type
                ( \(customType : CustomTypeGen.Output) ->
                    { path = srcPrefix ++ "types/" ++ customType.modulePath
                    , content =
                            "package "
                        ++  packageName
                        ++  ''
                            .types;
                            ''
                        ++  "\n"
                        ++  customType.moduleContent
                        ++  "\n"
                    }
                )
                customTypes

        let statementFiles
            : List Sdk.File.Type
            = Deps.Prelude.List.map
                QueryGen.Output
                Sdk.File.Type
                ( \(query : QueryGen.Output) ->
                    { path =
                        srcPrefix ++ "statements/" ++ query.statementModulePath
                    , content =
                            "package "
                        ++  packageName
                        ++  ''
                            .statements;
                            ''
                        ++  "\n"
                        ++  "import "
                        ++  packageName
                        ++  ''
                            .Statement;
                            ''
                        ++  "import "
                        ++  packageName
                        ++  ''
                            .codecs.Jdbc;
                            ''
                        ++  "import "
                        ++  packageName
                        ++  ''
                            .types.*;
                            ''
                        ++  "\n"
                        ++  query.statementModuleContents
                        ++  "\n"
                    }
                )
                queries

        let testStatementFiles
            : List Sdk.File.Type
            = Deps.Prelude.List.map
                QueryGen.Output
                Sdk.File.Type
                ( \(query : QueryGen.Output) ->
                    { path = testPrefix ++ "statements/" ++ query.testModulePath
                    , content =
                            "package "
                        ++  packageName
                        ++  ''
                            .statements;
                            ''
                        ++  "\n"
                        ++  "import static org.junit.jupiter.api.Assertions.*;"
                        ++  "\n\n"
                        ++  "import "
                        ++  packageName
                        ++  ''
                            .AbstractDatabaseIT;
                            ''
                        ++  "import "
                        ++  packageName
                        ++  ''
                            .types.*;
                            ''
                        ++  "import java.sql.SQLException;"
                        ++  "\n"
                        ++  "import java.time.*;"
                        ++  "\n"
                        ++  "import org.junit.jupiter.api.Test;"
                        ++  "\n\n"
                        ++  query.testModuleContents
                        ++  "\n"
                    }
                )
                queries

        let statementJava
            : Sdk.File.Type
            = { path = srcPrefix ++ "Statement.java"
              , content =
                  ''
                  package ${packageName};

                  import java.sql.Connection;
                  import java.sql.PreparedStatement;
                  import java.sql.ResultSet;
                  import java.sql.SQLException;

                  /**
                   * Implemented by each query's parameter+result class. Provides a uniform way to
                   * prepare and execute statements against a JDBC {@link java.sql.Connection}.
                   *
                   * <p>
                   * Generated from SQL queries using the <a href="https://pgenie.io">pGenie</a>
                   * code generator.
                   *
                   * @param <R> the result type returned by {@link #decodeResultSet} or
                   * {@link #decodeAffectedRows}
                   */
                  public interface Statement<R> {

                      /**
                       * The SQL text for this statement. Parameter placeholders use JDBC
                       * {@code ?} syntax; custom PostgreSQL types are cast explicitly, e.g.
                       * {@code ?::album_format}.
                       */
                      String sql();

                      /**
                       * Bind to the prepared statement's parameter slots.
                       */
                      void bindParams(PreparedStatement ps) throws SQLException;

                      /**
                       * Whether this statement returns rows (i.e. is a {@code SELECT} or contains
                       * a {@code RETURNING} clause).
                       */
                      boolean returnsRows();

                      /**
                       * Decode a result set into the statement's result type.
                       */
                      R decodeResultSet(ResultSet rs) throws SQLException;

                      /**
                       * Decode an affected-row count into the statement's result type.
                       */
                      R decodeAffectedRows(long affectedRows) throws SQLException;

                      /** Execute this statement using the provided JDBC connection. */
                      default R execute(Connection conn) throws SQLException {
                          try (PreparedStatement ps = conn.prepareStatement(sql())) {
                              bindParams(ps);
                              if (returnsRows()) {
                                  ps.execute();
                                  try (ResultSet rs = ps.getResultSet()) {
                                      return decodeResultSet(rs);
                                  }
                              } else {
                                  long affectedRows = ps.executeUpdate();
                                  return decodeAffectedRows(affectedRows);
                              }
                          }
                      }
                  }
                  ''
              }

        let jdbcJava
            : Sdk.File.Type
            = { path = srcPrefix ++ "codecs/Jdbc.java"
              , content =
                  ''
                  package ${packageName}.codecs;

                  import java.sql.PreparedStatement;
                  import java.sql.SQLException;

                  import org.postgresql.util.PGobject;

                  import io.codemine.java.postgresql.codecs.Codec;

                  /**
                   * JDBC binding utilities for the {@code postgresql-codecs} library.
                   *
                   * <p>
                   * Provides a thin bridge between driver-agnostic {@link Codec} instances
                   * and the PostgreSQL JDBC driver ({@code pgjdbc}). Values are encoded as
                   * text-format {@link PGobject} instances so that the driver sends the
                   * correct type OID.
                   */
                  public final class Jdbc {

                      private Jdbc() {
                      }

                      /**
                       * Binds a value to a prepared statement parameter using a codec.
                       *
                       * @param ps    the prepared statement
                       * @param index the 1-based parameter index
                       * @param codec the codec to use for encoding
                       * @param value the value to bind (may be {@code null})
                       * @param <A>   the value type
                       */
                      public static <A> void bind(PreparedStatement ps, int index, Codec<A> codec, A value) throws SQLException {
                          PGobject obj = new PGobject();
                          obj.setType(codec.typeSig());
                          if (value != null) {
                              obj.setValue(codec.encodeInTextToString(value));
                          }
                          ps.setObject(index, obj);
                      }

                  }
                  ''
              }

        let packageName2 = Deps.CodegenKit.Name.toTextInKebab input.name

        let migrationEntries =
              Deps.Prelude.Text.concatMapSep
                "\n"
                { name : Text, sql : Text }
                ( \(migration : { name : Text, sql : Text }) ->
                    let indented =
                          Deps.Lude.Extensions.Text.prefixEachLine
                            "        "
                            migration.sql

                    in      ''
                            ${"        "}"""
                            ${"        "}''
                        ++  indented
                        ++  "\"\"\","
                )
                input.migrations

        let abstractDatabaseIT
            : Sdk.File.Type
            = { path = testPrefix ++ "AbstractDatabaseIT.java"
              , content =
                  Templates.AbstractDatabaseIT.run
                    { packageName, migrationEntries }
              }

        let statementNamesSection =
              Deps.Prelude.Text.concatMapSep
                "\n"
                QueryGen.Output
                ( \(query : QueryGen.Output) ->
                    "- `" ++ query.statementModuleName ++ "`"
                )
                queries

        let typeNamesSection =
              Deps.Prelude.Text.concatMapSep
                "\n"
                CustomTypeGen.Output
                ( \(customType : CustomTypeGen.Output) ->
                    "- `" ++ customType.typeName ++ "`"
                )
                customTypes

        let projectName =
              Deps.CodegenKit.Name.toTextInPascal
                (Deps.CodegenKit.Name.concat input.space [ input.name ])

        let readmeMd
            : Sdk.File.Type
            = { path = "README.md"
              , content =
                  Templates.ReadmeMd.run
                    { projectName
                    , groupId = "io.pgenie.artifacts.${spacePkg}"
                    , packageName
                    , version =
                            Natural/show input.version.major
                        ++  "."
                        ++  Natural/show input.version.minor
                        ++  "."
                        ++  Natural/show input.version.patch
                    , statementNames = statementNamesSection
                    , typeNames = typeNamesSection
                    }
              }

        let pomXml
            : Sdk.File.Type
            = { path = "pom.xml"
              , content =
                  Templates.PomXml.run
                    { groupId = "io.pgenie.artifacts.${spacePkg}"
                    , artifactId = packageName2
                    , version =
                            Natural/show input.version.major
                        ++  "."
                        ++  Natural/show input.version.minor
                        ++  "."
                        ++  Natural/show input.version.patch
                    , projectName
                    , dbName = Deps.CodegenKit.Name.toTextInSnake input.name
                    }
              }

        in      [ pomXml
                , readmeMd
                , statementJava
                , jdbcJava
                , abstractDatabaseIT
                ]
              # customTypeFiles
              # statementFiles
              # testStatementFiles
            : List Sdk.File.Type

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let compiledQueries
            : Sdk.Compiled.Type (List (Optional QueryGen.Output))
            = Sdk.Compiled.traverseList
                Deps.Sdk.Project.Query
                (Optional QueryGen.Output)
                ( \(query : Deps.Sdk.Project.Query) ->
                    Deps.Typeclasses.Classes.Alternative.optional
                      Sdk.Compiled.Type
                      Sdk.Compiled.alternative
                      QueryGen.Output
                      (QueryGen.run config query)
                )
                input.queries

        let compiledQueries
            : Sdk.Compiled.Type (List QueryGen.Output)
            = Sdk.Compiled.map
                (List (Optional QueryGen.Output))
                (List QueryGen.Output)
                (Deps.Prelude.List.unpackOptionals QueryGen.Output)
                compiledQueries

        let compiledTypes
            : Sdk.Compiled.Type (List (Optional CustomTypeGen.Output))
            = Sdk.Compiled.traverseList
                Deps.Sdk.Project.CustomType
                (Optional CustomTypeGen.Output)
                ( \(ct : Deps.Sdk.Project.CustomType) ->
                    Deps.Typeclasses.Classes.Alternative.optional
                      Sdk.Compiled.Type
                      Sdk.Compiled.alternative
                      CustomTypeGen.Output
                      (CustomTypeGen.run config ct)
                )
                input.customTypes

        let compiledTypes
            : Sdk.Compiled.Type (List CustomTypeGen.Output)
            = Sdk.Compiled.map
                (List (Optional CustomTypeGen.Output))
                (List CustomTypeGen.Output)
                (Deps.Prelude.List.unpackOptionals CustomTypeGen.Output)
                compiledTypes

        let files
            : Sdk.Compiled.Type (List Sdk.File.Type)
            = Sdk.Compiled.map2
                (List QueryGen.Output)
                (List CustomTypeGen.Output)
                (List Sdk.File.Type)
                (combineOutputs config input)
                compiledQueries
                compiledTypes

        in  files

in  Algebra.module Input Output run
