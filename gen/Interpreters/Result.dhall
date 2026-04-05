let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let ResultRows = ./ResultRows.dhall

let Templates = ../Templates/package.dhall

let Input = Deps.Sdk.Project.Result

let ExtraCtx = { sqlExp : Text, paramBindCode : Text }

let Output =
      ExtraCtx ->
      Text ->
        { typeDecls : Text, statementImpl : Text, statementTypeArg : Text }

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
                      Templates.StatementImplNoResult.run
                        { sqlExp = ctx.sqlExp
                        , paramBindCode = ctx.paramBindCode
                        }
                  , statementTypeArg = "Long"
                  }
              )
          )

in  Algebra.module Input Output run
