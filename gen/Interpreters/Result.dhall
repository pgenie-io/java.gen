let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let ResolvedTarget = ../ResolvedTarget.dhall

let ResultRows = ./ResultRows.dhall

let Templates = ../Templates/package.dhall

let Input = Deps.Contract.Result

let Output =
      Text ->
        { statementImpl : Text
        , typeDecls : Text
        , statementTypeArg : Text
        , imports : ImportSet.Type
        }

let run =
      \(config : ResolvedTarget.Type) ->
      \(input : Input) ->
        merge
          { Void =
              Deps.Lude.Compiled.ok
                Output
                ( \(_ : Text) ->
                    { typeDecls = ""
                    , statementImpl = Templates.StatementImplNoResult.run {=}
                    , statementTypeArg = "Long"
                    , imports = ImportSet.empty
                    }
                )
          , RowsAffected =
              Deps.Lude.Compiled.ok
                Output
                ( \(_ : Text) ->
                    { typeDecls = ""
                    , statementImpl = Templates.StatementImplNoResult.run {=}
                    , statementTypeArg = "Long"
                    , imports = ImportSet.empty
                    }
                )
          , Rows = ResultRows.run config
          }
          input

in  Deps.Sdk.Sigs.Interpreter.module ResolvedTarget.Type Input Output run
