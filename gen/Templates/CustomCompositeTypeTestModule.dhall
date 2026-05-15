let Deps = ../Deps/package.dhall

let TestCase = { testName : Text, constructorArgs : Text }

let Params =
      { packageName : Text
      , typeName : Text
      , pgTypeName : Text
      , needsCodecsImport : Bool
      , testCases : List TestCase
      }

let run =
      \(params : Params) ->
        let codecImport =
              if    params.needsCodecsImport
              then  "import io.codemine.java.postgresql.codecs.*;\n"
              else  ""

        let combinationTests =
              Deps.Prelude.Text.concatMapSep
                "\n\n"
                TestCase
                ( \(tc : TestCase) ->
                    ''
                    @Test
                    void ${tc.testName}() throws SQLException {
                        var value = new ${params.typeName}(${tc.constructorArgs});
                        assertEquals(Optional.of(value), roundtrip(value));
                    }''
                )
                params.testCases

        in  ''
            package ${params.packageName}.types;

            import static org.junit.jupiter.api.Assertions.*;

            import ${params.packageName}.AbstractDatabaseIT;
            ${codecImport}import io.codemine.java.postgresql.jdbc.Statement;
            import java.sql.*;
            import java.time.*;
            import java.util.List;
            import java.util.Optional;
            import org.junit.jupiter.api.Test;

            class ${params.typeName}IT extends AbstractDatabaseIT {

                private Optional<${params.typeName}> roundtrip(${params.typeName} input) throws SQLException {
                    return execute(new Statement<Optional<${params.typeName}>>() {
                        @Override public String sql() { return "select ?::${params.pgTypeName}"; }
                        @Override public void bindParams(PreparedStatement ps) throws SQLException {
                            ${params.typeName}.CODEC.bind(ps, 1, input);
                        }
                        @Override public boolean returnsRows() { return true; }
                        @Override public Optional<${params.typeName}> decodeResultSet(ResultSet rs) throws SQLException {
                            rs.next();
                            return ${params.typeName}.CODEC.decodeOptional(rs, 0, 1);
                        }
                        @Override public Optional<${params.typeName}> decodeAffectedRows(long r) {
                            throw new UnsupportedOperationException();
                        }
                    });
                }

                @Test
                void roundtripNull() throws SQLException {
                    assertEquals(Optional.empty(), roundtrip(null));
                }

                ${Deps.Lude.Extensions.Text.indentNonEmpty 4 combinationTests}
            }
            ''

in  { Params, TestCase, run }
