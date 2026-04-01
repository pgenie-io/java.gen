let Algebra = ./Algebra/package.dhall

let Params = { typeName : Text, defaultConstruction : Text, hasResult : Bool }

in  Algebra.module
      Params
      ( \(params : Params) ->
          let verifyResult =
                if    params.hasResult
                then  ''
                          assertNotNull(result);
                      ''
                else  ''
                          assertTrue(result >= 0L);
                      ''

          in  ''
              class ${params.typeName}IT extends AbstractDatabaseIT {

                  @Test
                  void executesWithDefaultValues() throws SQLException {
                      var result = execute(new ${params.defaultConstruction});
                      ${verifyResult}
                  }
              }
              ''
      )
