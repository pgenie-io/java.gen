let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Params =
      { packageName : Text
      , typeName : Text
      , defaultArgs : List Text
      , hasResult : Bool
      , resultNullable : Bool
      , shouldTestIdentity : Bool
      , identityFieldNames : List Text
      , testRandomArgs : List Text
      , isMultipleCardinality : Bool
      , isOptionalCardinality : Bool
      }

in  Sdk.Sigs.template
      Params
      ( \(params : Params) ->
          let randomArgList = Prelude.Text.concatSep ", " params.testRandomArgs

          let defaultTestCase =
                ''
                @Test
                void executesWithDefaultValues() throws SQLException {
                    var result = execute(new ${params.typeName}(${Prelude.Text.concatSep
                                                                    ", "
                                                                    params.defaultArgs}));
                    ${Lude.Text.indentNonEmpty
                        4
                        ( if    params.hasResult
                          then  if    params.resultNullable
                                then  "assertNull(result);"
                                else  "assertNotNull(result);"
                          else  "assertTrue(result >= 0L);"
                        )}
                }''

          let identityTestCase =
                ''
                @Test
                void satisfiesIdentityProperty() throws SQLException {
                    var statement = new ${params.typeName}(${randomArgList});
                    var result = execute(statement);
                    ${Lude.Text.indentNonEmpty
                        4
                        ( let identityFieldAccessors =
                                Prelude.Text.concatSep
                                  ", "
                                  ( Prelude.List.map
                                      Text
                                      Text
                                      ( \(fieldName : Text) ->
                                          "statement.${fieldName}()"
                                      )
                                      params.identityFieldNames
                                  )

                          in  if    params.isOptionalCardinality
                              then  ''
                                    assertTrue(result.isPresent());
                                    assertEquals(
                                        new ${params.typeName}.ResultRow(${identityFieldAccessors}),
                                        result.get());''
                              else  if params.isMultipleCardinality
                              then  ''
                                    assertEquals(1, result.size());
                                    assertEquals(
                                        new ${params.typeName}.ResultRow(${identityFieldAccessors}),
                                        result.get(0));''
                              else  ''
                                    assertEquals(
                                        new ${params.typeName}.Result(${identityFieldAccessors}),
                                        result);''
                        )}
                }''

          in  ''
              package ${params.packageName}.statements;

              import static org.junit.jupiter.api.Assertions.*;

              import ${params.packageName}.AbstractDatabaseIT;
              import ${params.packageName}.types.*;
              import io.codemine.java.postgresql.jdbc.Codec;
              import io.codemine.java.postgresql.codecs.*;
              import java.util.List;
              import java.sql.SQLException;
              import java.time.*;
              import java.util.Optional;
              import org.junit.jupiter.api.Test;

              class ${params.typeName}IT extends AbstractDatabaseIT {
                  ${Lude.Text.indentNonEmpty
                      4
                      ( if    params.shouldTestIdentity
                        then  identityTestCase
                        else  defaultTestCase
                      )}
              }
              ''
      )
