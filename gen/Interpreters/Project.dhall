let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Lude = Deps.Lude

let Model = Deps.Sdk.Project

let Templates = ../Templates/package.dhall

let QueryGen = ./Query.dhall

let CustomTypeGen = ./CustomType.dhall

let Input = Model.Project

let Output = List Lude.File.Type

let toFlatLower =
      \(name : Model.Name) -> Deps.Prelude.Text.replace "_" "" name.inSnakeCase

let combineOutputs =
      \(input : Input) ->
      \(queries : List QueryGen.Output) ->
      \(customTypes : List CustomTypeGen.Output) ->
        let spacePkg = toFlatLower input.space

        let namePkg = toFlatLower input.name

        let packageName = "io.pgenie.artifacts.${spacePkg}.${namePkg}"

        let srcPrefix =
              "src/main/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"

        let testPrefix =
              "src/test/java/io/pgenie/artifacts/${spacePkg}/${namePkg}/"

        let customTypeFiles
            : List Lude.File.Type
            = Deps.Prelude.List.map
                CustomTypeGen.Output
                Lude.File.Type
                ( \(customType : CustomTypeGen.Output) ->
                    { path = srcPrefix ++ "types/" ++ customType.modulePath
                    , content = customType.moduleContent
                    }
                )
                customTypes

        let testCustomTypeFiles
            : List Lude.File.Type
            = Deps.Prelude.List.map
                CustomTypeGen.Output
                Lude.File.Type
                ( \(customType : CustomTypeGen.Output) ->
                    { path = testPrefix ++ "types/" ++ customType.testModulePath
                    , content = customType.testModuleContent
                    }
                )
                customTypes

        let statementFiles
            : List Lude.File.Type
            = Deps.Prelude.List.map
                QueryGen.Output
                Lude.File.Type
                ( \(query : QueryGen.Output) ->
                    { path =
                        srcPrefix ++ "statements/" ++ query.statementModulePath
                    , content = query.statementModuleContents
                    }
                )
                queries

        let testStatementFiles
            : List Lude.File.Type
            = Deps.Prelude.List.map
                QueryGen.Output
                Lude.File.Type
                ( \(query : QueryGen.Output) ->
                    { path = testPrefix ++ "statements/" ++ query.testModulePath
                    , content = query.testModuleContents
                    }
                )
                queries

        let artifactId = input.name.inKebabCase

        let migrations =
              Deps.Prelude.List.map
                { name : Text, sql : Text }
                Text
                (\(migration : { name : Text, sql : Text }) -> migration.sql)
                input.migrations

        let abstractDatabaseIT
            : Lude.File.Type
            = { path = testPrefix ++ "AbstractDatabaseIT.java"
              , content =
                  Templates.AbstractDatabaseIT.run { packageName, migrations }
              }

        let statementNamesSection =
              Deps.Prelude.Text.concatMapSep
                "\n"
                QueryGen.Output
                ( \(query : QueryGen.Output) ->
                    "- `${query.statementModuleName}`"
                )
                queries

        let typeNamesSection =
              Deps.Prelude.Text.concatMapSep
                "\n"
                CustomTypeGen.Output
                ( \(customType : CustomTypeGen.Output) ->
                    "- `${customType.typeName}`"
                )
                customTypes

        let firstStatementName
            : Optional Text
            = Deps.Prelude.Optional.fold
                QueryGen.Output
                (Deps.Prelude.List.head QueryGen.Output queries)
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
                    , groupId = "io.pgenie.artifacts.${spacePkg}"
                    , artifactId
                    , packageName
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
                    { groupId = "io.pgenie.artifacts.${spacePkg}"
                    , artifactId
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
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let compiledQueries
            : Lude.Compiled.Type (List (Optional QueryGen.Output))
            = Lude.Compiled.traverseList
                Deps.Sdk.Project.Query
                (Optional QueryGen.Output)
                ( \(query : Deps.Sdk.Project.Query) ->
                    Deps.Typeclasses.Classes.Alternative.optional
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
                (Deps.Prelude.List.unpackOptionals QueryGen.Output)
                compiledQueries

        let compiledTypes
            : Lude.Compiled.Type (List (Optional CustomTypeGen.Output))
            = Lude.Compiled.traverseList
                Deps.Sdk.Project.CustomType
                (Optional CustomTypeGen.Output)
                ( \(ct : Deps.Sdk.Project.CustomType) ->
                    Deps.Typeclasses.Classes.Alternative.optional
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
                (Deps.Prelude.List.unpackOptionals CustomTypeGen.Output)
                compiledTypes

        let files
            : Lude.Compiled.Type (List Lude.File.Type)
            = Lude.Compiled.map2
                (List QueryGen.Output)
                (List CustomTypeGen.Output)
                (List Lude.File.Type)
                (combineOutputs input)
                compiledQueries
                compiledTypes

        in  files

in  Algebra.module Input Output run
