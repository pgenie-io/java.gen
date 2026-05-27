let Deps = ../Deps/package.dhall

let Variant = { variantName : Text }

let Params =
      { packageName : Text
      , typeName : Text
      , pgTypeName : Text
      , variants : List Variant
      }

let run =
      \(params : Params) ->
        let variantTests =
              Deps.Prelude.Text.concatMapSep
                "\n\n"
                Variant
                ( \(v : Variant) ->
                    ''
                    @Test
                    void roundtrip${v.variantName}() throws SQLException {
                        assertEquals(Optional.of(${params.typeName}.${v.variantName}), roundtrip(Optional.of(${params.typeName}.${v.variantName})));
                    }''
                )
                params.variants

        in  ''
            package ${params.packageName}.types;

            import static org.junit.jupiter.api.Assertions.*;

            import ${params.packageName}.AbstractDatabaseIT;
            import io.codemine.java.postgresql.jdbc.Statement;
            import java.sql.*;
            import java.util.Optional;
            import org.junit.jupiter.api.Test;

            class ${params.typeName}IT extends AbstractDatabaseIT {

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

                @Test
                void roundtripNull() throws SQLException {
                    assertEquals(Optional.empty(), roundtrip(Optional.empty()));
                }

                ${Deps.Lude.Text.indentNonEmpty 4 variantTests}
            }
            ''

in  { Params, Variant, run }
