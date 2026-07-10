let Contract = ./Deps/Contract.dhall

let Prelude = ./Deps/Prelude.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

let Config = { useOptional : Bool }

let resolveConfig =
      \(config : Optional Config) ->
        Prelude.Optional.fold
          Config
          config
          Config
          (\(c : Config) -> c)
          { useOptional = False }

in  Contract.module
      Config
      ( \(config : Optional Config) ->
          ProjectInterpreter.run (resolveConfig config)
      )
