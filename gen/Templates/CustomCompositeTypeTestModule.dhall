let Deps = ../Deps/package.dhall

let TestCase = { testName : Text, constructorArgs : Text }

let Params =
      { packageName : Text
      , typeName : Text
      , pgTypeName : Text
      , needsCodecsImport : Bool
      , testCases : List TestCase
      , useOptional : Bool
      }

let run =
      \(params : Params) ->
        let codecImport =
              if    params.needsCodecsImport
              then  ''
                    import io.codemine.java.postgresql.codecs.*;
                    ''
              else  ""

        let optionalImport =
              if    params.useOptional
              then  ''
                    import java.util.Optional;
                    ''
              else  ""

        let combinationTests =
              Deps.Prelude.Text.concatMapSep
                "\n\n"
                TestCase
                ( \(tc : TestCase) ->
                    if    params.useOptional
                    then  ''
                          @Test
                          void ${tc.testName}() throws SQLException {
                              var value = new ${params.typeName}(${tc.constructorArgs});
                              assertEquals(Optional.of(value), roundtrip(Optional.of(value)));
                          }''
                    else  ''
                          @Test
                          void ${tc.testName}() throws SQLException {
                              var value = new ${params.typeName}(${tc.constructorArgs});
                              assertEquals(value, roundtrip(value));
                          }''
                )
                params.testCases

        let roundtripMethod =
              if    params.useOptional
              then  ''
                    private Optional<${params.typeName}> roundtrip(Optional<${params.typeName}> input) throws SQLException {
                        return execute(new Statement<Optional<${params.typeName}>>() {
                            @Override public String sql() { return "select ?::${params.pgTypeName}"; }
                            @Override public void bindParams(PreparedStatement ps) throws SQLException {
                                ${params.typeName}.CODEC.bind(ps, 1, input.orElse(null));
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
                    ''
              else  ''
                    private ${params.typeName} roundtrip(${params.typeName} input) throws SQLException {
                        return execute(new Statement<${params.typeName}>() {
                            @Override public String sql() { return "select ?::${params.pgTypeName}"; }
                            @Override public void bindParams(PreparedStatement ps) throws SQLException {
                                ${params.typeName}.CODEC.bind(ps, 1, input);
                            }
                            @Override public boolean returnsRows() { return true; }
                            @Override public ${params.typeName} decodeResultSet(ResultSet rs) throws SQLException {
                                rs.next();
                                return ${params.typeName}.CODEC.decodeNullable(rs, 0, 1);
                            }
                            @Override public ${params.typeName} decodeAffectedRows(long r) {
                                throw new UnsupportedOperationException();
                            }
                        });
                    }
                    ''

        let nullTest =
              if    params.useOptional
              then  ''
                    @Test
                    void roundtripNull() throws SQLException {
                        assertEquals(Optional.empty(), roundtrip(Optional.empty()));
                    }
                    ''
              else  ''
                    @Test
                    void roundtripNull() throws SQLException {
                        assertNull(roundtrip(null));
                    }
                    ''

        in  ''
            package ${params.packageName}.types;

            import static org.junit.jupiter.api.Assertions.*;

            import ${params.packageName}.AbstractDatabaseIT;
            ${codecImport}import io.codemine.java.postgresql.jdbc.Statement;
            import java.sql.*;
            import java.time.*;
            import java.util.List;
            ${optionalImport}import org.junit.jupiter.api.Test;

            class ${params.typeName}IT extends AbstractDatabaseIT {

                ${Deps.Lude.Text.indentNonEmpty 4 roundtripMethod}

                ${Deps.Lude.Text.indentNonEmpty 4 nullTest}

                ${Deps.Lude.Text.indentNonEmpty 4 combinationTests}
            }
            ''

in  { Params, TestCase, run }
