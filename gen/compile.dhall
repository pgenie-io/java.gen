let Deps = ./Deps/package.dhall

let Sdk = Deps.Sdk

let Config = ./Config.dhall

let ProjectInterpreter = ./Interpreters/Project.dhall

in  \(config : Optional Config) ->
    \(project : Sdk.Project.Project) ->
      let useOptional =
            Deps.Prelude.Optional.fold
              Config
              config
              Bool
              (\(c : Config) -> c.useOptional)
              False

      let flatten =
            \(name : Sdk.Project.Name) ->
              Deps.Prelude.Text.replace "_" "" name.inSnakeCase

      let spacePkg = flatten project.space

      let namePkg = flatten project.name

      let interpreterConfig =
            { packageName = "io.pgenie.artifacts.${spacePkg}.${namePkg}"
            , srcPrefix =
                "src/main/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"
            , testPrefix =
                "src/test/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"
            , groupId = "io.pgenie.artifacts.${spacePkg}"
            , artifactId = project.name.inKebabCase
            , useOptional
            }

      in  ProjectInterpreter.run interpreterConfig project
