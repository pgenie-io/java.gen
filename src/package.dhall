let Contract = ./Deps/Contract.dhall

let Config = ./Config.dhall

let InterpreterConfig = ./InterpreterConfig.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

let compile =
      \(config : Optional Config) ->
      \(project : Contract.Project) ->
        ProjectInterpreter.run
          (InterpreterConfig.resolve config project)
          project

in  Contract.module Config compile
