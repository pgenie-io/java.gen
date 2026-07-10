let ResolvedTarget = ../ResolvedTarget.dhall

let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Model = ../Deps/Contract.dhall

let Typeclasses = ../Deps/Typeclasses.dhall

let Templates = ../Templates/package.dhall

let QueryGen = ./Query.dhall

let CustomTypeGen = ./CustomType.dhall

let Input = Model.Project

let Output = List Lude.File.Type

let combineOutputs =
      \(config : ResolvedTarget.Type) ->
      \(input : Input) ->
      \(queries : List QueryGen.Output) ->
      \(customTypes : List CustomTypeGen.Output) ->
        let customTypeFiles
            : List Lude.File.Type
            = Prelude.List.map
                CustomTypeGen.Output
                Lude.File.Type
                ( \(customType : CustomTypeGen.Output) ->
                    { path =
                        config.srcPrefix ++ "types/" ++ customType.modulePath
                    , content = customType.moduleContent
                    }
                )
                customTypes

        let testCustomTypeFiles
            : List Lude.File.Type
            = Prelude.List.map
                CustomTypeGen.Output
                Lude.File.Type
                ( \(customType : CustomTypeGen.Output) ->
                    { path =
                            config.testPrefix
                        ++  "types/"
                        ++  customType.testModulePath
                    , content = customType.testModuleContent
                    }
                )
                customTypes

        let statementFiles
            : List Lude.File.Type
            = Prelude.List.map
                QueryGen.Output
                Lude.File.Type
                ( \(query : QueryGen.Output) ->
                    { path =
                            config.srcPrefix
                        ++  "statements/"
                        ++  query.statementModulePath
                    , content = query.statementModuleContents
                    }
                )
                queries

        let testStatementFiles
            : List Lude.File.Type
            = Prelude.List.map
                QueryGen.Output
                Lude.File.Type
                ( \(query : QueryGen.Output) ->
                    { path =
                            config.testPrefix
                        ++  "statements/"
                        ++  query.testModulePath
                    , content = query.testModuleContents
                    }
                )
                queries

        let migrations =
              Prelude.List.map
                { name : Text, sql : Text }
                Text
                (\(migration : { name : Text, sql : Text }) -> migration.sql)
                input.migrations

        let abstractDatabaseIT
            : Lude.File.Type
            = { path = config.testPrefix ++ "AbstractDatabaseIT.java"
              , content =
                  Templates.AbstractDatabaseIT.run
                    { packageName = config.packageName, migrations }
              }

        let statementNamesSection =
              Prelude.Text.concatMapSep
                "\n"
                QueryGen.Output
                ( \(query : QueryGen.Output) ->
                    "- `${query.statementModuleName}`"
                )
                queries

        let typeNamesSection =
              Prelude.Text.concatMapSep
                "\n"
                CustomTypeGen.Output
                ( \(customType : CustomTypeGen.Output) ->
                    "- `${customType.typeName}`"
                )
                customTypes

        let firstStatementName
            : Optional Text
            = Prelude.Optional.fold
                QueryGen.Output
                (Prelude.List.head QueryGen.Output queries)
                (Optional Text)
                (\(q : QueryGen.Output) -> Some q.statementModuleName)
                (None Text)

        let projectName = input.space.inPascalCase ++ input.name.inPascalCase

        let version =
              "${Natural/show
                   input.version.major}.${Natural/show
                                            input.version.minor}.${Natural/show
                                                                     input.version.patch}"

        let readmeMd
            : Lude.File.Type
            = { path = "README.md"
              , content =
                  Templates.ReadmeMd.run
                    { projectName
                    , groupId = config.groupId
                    , artifactId = config.artifactId
                    , packageName = config.packageName
                    , version
                    , statementNames = statementNamesSection
                    , typeNames = typeNamesSection
                    , firstStatementName
                    }
              }

        let pomXml
            : Lude.File.Type
            = { path = "pom.xml"
              , content =
                  Templates.PomXml.run
                    { groupId = config.groupId
                    , artifactId = config.artifactId
                    , version
                    , projectName
                    , dbName = input.name.inSnakeCase
                    }
              }

        in      [ pomXml, readmeMd, abstractDatabaseIT ]
              # customTypeFiles
              # testCustomTypeFiles
              # statementFiles
              # testStatementFiles
            : List Lude.File.Type

let run =
      \(config : ResolvedTarget.Type) ->
      \(input : Input) ->
        let compiledQueries
            : Lude.Compiled.Type (List (Optional QueryGen.Output))
            = Lude.Compiled.traverseList
                Model.Query
                (Optional QueryGen.Output)
                ( \(query : Model.Query) ->
                    Typeclasses.Classes.Alternative.optional
                      Lude.Compiled.Type
                      Lude.Compiled.alternative
                      QueryGen.Output
                      (QueryGen.run config query)
                )
                input.queries

        let compiledQueries
            : Lude.Compiled.Type (List QueryGen.Output)
            = Lude.Compiled.map
                (List (Optional QueryGen.Output))
                (List QueryGen.Output)
                (Prelude.List.unpackOptionals QueryGen.Output)
                compiledQueries

        let compiledTypes
            : Lude.Compiled.Type (List (Optional CustomTypeGen.Output))
            = Lude.Compiled.traverseList
                Model.CustomType
                (Optional CustomTypeGen.Output)
                ( \(ct : Model.CustomType) ->
                    Typeclasses.Classes.Alternative.optional
                      Lude.Compiled.Type
                      Lude.Compiled.alternative
                      CustomTypeGen.Output
                      (CustomTypeGen.run config ct)
                )
                input.customTypes

        let compiledTypes
            : Lude.Compiled.Type (List CustomTypeGen.Output)
            = Lude.Compiled.map
                (List (Optional CustomTypeGen.Output))
                (List CustomTypeGen.Output)
                (Prelude.List.unpackOptionals CustomTypeGen.Output)
                compiledTypes

        let files
            : Lude.Compiled.Type (List Lude.File.Type)
            = Lude.Compiled.map2
                (List QueryGen.Output)
                (List CustomTypeGen.Output)
                (List Lude.File.Type)
                (combineOutputs config input)
                compiledQueries
                compiledTypes

        in  files

in  Sdk.Sigs.Interpreter.module ResolvedTarget.Type Input Output run
