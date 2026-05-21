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

      let interpreterConfig =
            { rootModuleName = project.name.inSnakeCase
            , packageName =
                "io.pgenie.artifacts.${Deps.Prelude.Text.replace
                                         "_"
                                         ""
                                         project.space.inSnakeCase}.${Deps.Prelude.Text.replace
                                                                        "_"
                                                                        ""
                                                                        project.name.inSnakeCase}"
            , useOptional
            }

      in  ProjectInterpreter.run interpreterConfig project
