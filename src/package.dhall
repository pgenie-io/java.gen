let Sdk = ./Deps/Sdk.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

let Config = { useOptional : Bool }

let defaultConfig = { useOptional = False }

in  Sdk.Sigs.generator Config defaultConfig ProjectInterpreter.run
