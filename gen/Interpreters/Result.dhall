let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let ResultRows = ./ResultRows.dhall

let Input = Deps.Sdk.Project.Result

let ExtraCtx = { sqlExp : Text, paramBindCode : Text }

let Output = ExtraCtx -> Text -> { typeDecls : Text, statementImpl : Text }

let Result = Deps.Sdk.Compiled.Type Output

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Deps.Prelude.Optional.fold
          ResultRows.Input
          input
          Result
          (ResultRows.run config)
          ( Deps.Sdk.Compiled.ok
              Output
              ( \(ctx : ExtraCtx) ->
                \(typeNameBase : Text) ->
                  { typeDecls = ""
                  , statementImpl =
                          ''
                              @Override
                              public String sql() {
                          ''
                      ++  "        return \"\"\""
                      ++  Deps.Lude.Extensions.Text.indent
                            15
                            (     "\n"
                              ++  ctx.sqlExp
                              ++  ''

                                  """;''
                            )
                      ++  ''

                              }

                              @Override
                              public void bindParams(PreparedStatement ps) throws SQLException {
                          ''
                      ++  ctx.paramBindCode
                      ++  ''
                              }

                              /**
                               * Returns the number of rows affected by the statement.
                               */
                              @Override
                              public boolean returnsRows() {
                                  return false;
                              }

                              /**
                               * Returns the number of rows affected by the statement.
                               *
                               * <p>
                               * Uses {@code affectedRows} forwarded from
                               * {@link java.sql.PreparedStatement#executeUpdate()}.
                               */
                              @Override
                              public Long decodeAffectedRows(long affectedRows) throws SQLException {
                                  return affectedRows;
                              }

                              @Override
                              public Long decodeResultSet(ResultSet rs) {
                                  throw new UnsupportedOperationException();
                          ''
                      ++  "    }"
                  }
              )
          )

in  Algebra.module Input Output run
