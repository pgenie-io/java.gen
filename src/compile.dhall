let Contract = ./Deps/Contract.dhall

let Config = ./Config.dhall

let InterpreterConfig = ./InterpreterConfig.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

in  \(config : Optional Config) ->
    \(project : Contract.Project) ->
      ProjectInterpreter.run (InterpreterConfig.resolve config project) project
