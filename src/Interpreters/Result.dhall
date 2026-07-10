let Sdk = ../Deps/Sdk.dhall

let Lude = ../Deps/Lude.dhall

let Contract = ../Deps/Contract.dhall

let ImportSet = ../Structures/ImportSet.dhall

let ResultRows = ./ResultRows.dhall

let Templates = ../Templates/package.dhall

let Config = { useOptional : Bool }

let Input = Contract.Result

let Output =
      Text ->
        { statementImpl : Text
        , typeDecls : Text
        , statementTypeArg : Text
        , imports : ImportSet.Type
        }

let run =
      \(config : Config) ->
      \(input : Input) ->
        merge
          { Void =
              Lude.Compiled.ok
                Output
                ( \(_ : Text) ->
                    { typeDecls = ""
                    , statementImpl = Templates.StatementImplNoResult.run {=}
                    , statementTypeArg = "Long"
                    , imports = ImportSet.empty
                    }
                )
          , RowsAffected =
              Lude.Compiled.ok
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

in  Sdk.Sigs.Interpreter.module Config Input Output run
