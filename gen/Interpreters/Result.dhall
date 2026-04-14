let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let ResultRows = ./ResultRows.dhall

let Templates = ../Templates/package.dhall

let Input = Deps.Sdk.Project.Result

let Output =
      Text ->
        { statementImpl : Text
        , typeDecls : Text
        , statementTypeArg : Text
        , imports : List Text
        , needsCustomTypeImport : Bool
        }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        merge
          { None =
              Deps.Sdk.Compiled.ok
                Output
                ( \(_ : Text) ->
                    { typeDecls = ""
                    , statementImpl = Templates.StatementImplNoResult.run {=}
                    , statementTypeArg = "Long"
                    , imports = [] : List Text
                    , needsCustomTypeImport = False
                    }
                )
          , Some = ResultRows.run config
          }
          input

in  Algebra.module Input Output run
