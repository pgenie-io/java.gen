let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Variant = { variantName : Text }

let Params =
      { packageName : Text
      , typeName : Text
      , pgTypeName : Text
      , variants : List Variant
      , useOptional : Bool
      }

let run =
      \(params : Params) ->
        let optionalImport =
              if    params.useOptional
              then  ''
                    import java.util.Optional;
                    ''
              else  ""

        let variantTests =
              Prelude.Text.concatMapSep
                "\n\n"
                Variant
                ( \(v : Variant) ->
                    if    params.useOptional
                    then  ''
                          @Test
                          void roundtrip${v.variantName}() throws SQLException {
                              assertEquals(Optional.of(${params.typeName}.${v.variantName}), roundtrip(Optional.of(${params.typeName}.${v.variantName})));
                          }''
                    else  ''
                          @Test
                          void roundtrip${v.variantName}() throws SQLException {
                              assertEquals(${params.typeName}.${v.variantName}, roundtrip(${params.typeName}.${v.variantName}));
                          }''
                )
                params.variants

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
            import io.codemine.java.postgresql.jdbc.Statement;
            import java.sql.*;
            ${optionalImport}import org.junit.jupiter.api.Test;

            class ${params.typeName}IT extends AbstractDatabaseIT {

                ${Lude.Text.indentNonEmpty 4 roundtripMethod}

                ${Lude.Text.indentNonEmpty 4 nullTest}

                ${Lude.Text.indentNonEmpty 4 variantTests}
            }
            ''

in  { Params, Variant, run }
