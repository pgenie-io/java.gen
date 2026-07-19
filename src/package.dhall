let Sdk = ./Deps/Sdk.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

let Config =
      { useOptional : Bool
      , groupId : Optional Text
      , artifactId : Optional Text
      , rootPackage : Optional Text
      }

let Config/default =
      { useOptional = False
      , groupId = None Text
      , artifactId = None Text
      , rootPackage = None Text
      }

in  Sdk.Sigs.generator Config Config/default ProjectInterpreter.run
