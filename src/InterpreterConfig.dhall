let Contract = ./Deps/Contract.dhall

let Prelude = ./Deps/Prelude.dhall

let Config = ./Config.dhall

let InterpreterConfig =
      { packageName : Text
      , srcPrefix : Text
      , testPrefix : Text
      , groupId : Text
      , artifactId : Text
      , useOptional : Bool
      }

let resolve =
      \(config : Optional Config) ->
      \(project : Contract.Project) ->
        let useOptional =
              Prelude.Optional.fold
                Config
                config
                Bool
                (\(c : Config) -> c.useOptional)
                False

        let flatten =
              \(name : Contract.Name) ->
                Prelude.Text.replace "_" "" name.inSnakeCase

        let spacePkg = flatten project.space

        let namePkg = flatten project.name

        in    { packageName = "io.pgenie.artifacts.${spacePkg}.${namePkg}"
              , srcPrefix =
                  "src/main/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"
              , testPrefix =
                  "src/test/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"
              , groupId = "io.pgenie.artifacts.${spacePkg}"
              , artifactId = project.name.inKebabCase
              , useOptional
              }
            : InterpreterConfig

in  { Type = InterpreterConfig, resolve }
