let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let ResultRows = ./ResultRows.dhall

let Templates = ../Templates/package.dhall

let Input = Deps.Sdk.Project.Result

let Output =
      Text ->
        { statementImpl : Text
        , typeDecls : Text
        , statementTypeArg : Text
        , imports : ImportSet.Type
        }

let run =
      \(config : Algebra.Config) ->
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

in  Algebra.module Input Output run
