let Sdk = ./Deps/Sdk.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

let Config = { useOptional : Bool }

let Config/default = { useOptional = False }

in  Sdk.Sigs.generator Config Config/default ProjectInterpreter.run
