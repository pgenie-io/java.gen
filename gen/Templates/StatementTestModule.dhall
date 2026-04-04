let Algebra = ./Algebra/package.dhall

let Deps = ../Deps/package.dhall

let Params =
      { packageName : Text
      , typeName : Text
      , defaultArgs : List Text
      , hasResult : Bool
      }

in  Algebra.module
      Params
      ( \(params : Params) ->
          ''
          package ${params.packageName}.statements;

          import static org.junit.jupiter.api.Assertions.*;

          import ${params.packageName}.AbstractDatabaseIT;
          import ${params.packageName}.types.*;
          import java.sql.SQLException;
          import java.time.*;
          import java.util.Optional;
          import org.junit.jupiter.api.Test;

          class ${params.typeName}IT extends AbstractDatabaseIT {

              @Test
              void executesWithDefaultValues() throws SQLException {
                  var result = execute(new ${params.typeName}(${Deps.Prelude.Text.concatSep
                                                                  ", "
                                                                  params.defaultArgs}));
                  ${if    params.hasResult
                    then  ''
                          assertNotNull(result);
                          ''
                    else  ''
                          assertTrue(result >= 0L);
                          ''}
              }
          }
          ''
      )
