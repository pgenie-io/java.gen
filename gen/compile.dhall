let Deps = ./Deps/package.dhall

let Sdk = Deps.Sdk

let CodegenKit = Deps.CodegenKit

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
            { rootModuleName = Deps.CodegenKit.Name.toTextInSnake project.name
            , packageName =
                "io.pgenie.artifacts.${Deps.Prelude.Text.replace
                                         "_"
                                         ""
                                         ( Deps.CodegenKit.Name.toTextInSnake
                                             project.space
                                         )}.${Deps.Prelude.Text.replace
                                                "_"
                                                ""
                                                ( Deps.CodegenKit.Name.toTextInSnake
                                                    project.name
                                                )}"
            , useOptional
            }

      in  ProjectInterpreter.run interpreterConfig project
