let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Templates = ../Templates/package.dhall

let QueryGen = ./Query.dhall

let CustomTypeGen = ./CustomType.dhall

let Input = Model.Project

let Output = List Sdk.File.Type

let toFlatLower =
      \(name : Model.Name) ->
        Deps.Prelude.Text.replace
          "_"
          ""
          (Deps.CodegenKit.Name.toTextInSnake name)

let combineOutputs =
      \(config : Algebra.Config) ->
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
            : List Sdk.File.Type
            = Deps.Prelude.List.map
                CustomTypeGen.Output
                Sdk.File.Type
                ( \(customType : CustomTypeGen.Output) ->
                    { path = srcPrefix ++ "types/" ++ customType.modulePath
                    , content =
                        Templates.CustomTypeFileWrapper.run
                          { packageName, content = customType.moduleContent }
                    }
                )
                customTypes

        let statementFiles
            : List Sdk.File.Type
            = Deps.Prelude.List.map
                QueryGen.Output
                Sdk.File.Type
                ( \(query : QueryGen.Output) ->
                    { path =
                        srcPrefix ++ "statements/" ++ query.statementModulePath
                    , content =
                        Templates.StatementFileWrapper.run
                          { packageName
                          , content = query.statementModuleContents
                          }
                    }
                )
                queries

        let testStatementFiles
            : List Sdk.File.Type
            = Deps.Prelude.List.map
                QueryGen.Output
                Sdk.File.Type
                ( \(query : QueryGen.Output) ->
                    { path = testPrefix ++ "statements/" ++ query.testModulePath
                    , content =
                        Templates.StatementTestFileWrapper.run
                          { packageName, content = query.testModuleContents }
                    }
                )
                queries

        let statementJava
            : Sdk.File.Type
            = { path = srcPrefix ++ "Statement.java"
              , content = Templates.StatementInterface.run { packageName }
              }

        let jdbcJava
            : Sdk.File.Type
            = { path = srcPrefix ++ "codecs/Jdbc.java"
              , content = Templates.JdbcModule.run { packageName }
              }

        let packageName2 = Deps.CodegenKit.Name.toTextInKebab input.name

        let migrations =
              Deps.Prelude.List.map
                { name : Text, sql : Text }
                Text
                (\(migration : { name : Text, sql : Text }) -> migration.sql)
                input.migrations

        let abstractDatabaseIT
            : Sdk.File.Type
            = { path = testPrefix ++ "AbstractDatabaseIT.java"
              , content =
                  Templates.AbstractDatabaseIT.run { packageName, migrations }
              }

        let statementNamesSection =
              Deps.Prelude.Text.concatMapSep
                "\n"
                QueryGen.Output
                ( \(query : QueryGen.Output) ->
                    "- `" ++ query.statementModuleName ++ "`"
                )
                queries

        let typeNamesSection =
              Deps.Prelude.Text.concatMapSep
                "\n"
                CustomTypeGen.Output
                ( \(customType : CustomTypeGen.Output) ->
                    "- `" ++ customType.typeName ++ "`"
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

        let projectName =
              Deps.CodegenKit.Name.toTextInPascal
                (Deps.CodegenKit.Name.concat input.space [ input.name ])

        let readmeMd
            : Sdk.File.Type
            = { path = "README.md"
              , content =
                  Templates.ReadmeMd.run
                    { projectName
                    , groupId = "io.pgenie.artifacts.${spacePkg}"
                    , artifactId = packageName2
                    , packageName
                    , version =
                            Natural/show input.version.major
                        ++  "."
                        ++  Natural/show input.version.minor
                        ++  "."
                        ++  Natural/show input.version.patch
                    , statementNames = statementNamesSection
                    , typeNames = typeNamesSection
                    , firstStatementName
                    }
              }

        let pomXml
            : Sdk.File.Type
            = { path = "pom.xml"
              , content =
                  Templates.PomXml.run
                    { groupId = "io.pgenie.artifacts.${spacePkg}"
                    , artifactId = packageName2
                    , version =
                            Natural/show input.version.major
                        ++  "."
                        ++  Natural/show input.version.minor
                        ++  "."
                        ++  Natural/show input.version.patch
                    , projectName
                    , dbName = Deps.CodegenKit.Name.toTextInSnake input.name
                    }
              }

        in      [ pomXml
                , readmeMd
                , statementJava
                , jdbcJava
                , abstractDatabaseIT
                ]
              # customTypeFiles
              # statementFiles
              # testStatementFiles
            : List Sdk.File.Type

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let compiledQueries
            : Sdk.Compiled.Type (List (Optional QueryGen.Output))
            = Sdk.Compiled.traverseList
                Deps.Sdk.Project.Query
                (Optional QueryGen.Output)
                ( \(query : Deps.Sdk.Project.Query) ->
                    Deps.Typeclasses.Classes.Alternative.optional
                      Sdk.Compiled.Type
                      Sdk.Compiled.alternative
                      QueryGen.Output
                      (QueryGen.run config query)
                )
                input.queries

        let compiledQueries
            : Sdk.Compiled.Type (List QueryGen.Output)
            = Sdk.Compiled.map
                (List (Optional QueryGen.Output))
                (List QueryGen.Output)
                (Deps.Prelude.List.unpackOptionals QueryGen.Output)
                compiledQueries

        let compiledTypes
            : Sdk.Compiled.Type (List (Optional CustomTypeGen.Output))
            = Sdk.Compiled.traverseList
                Deps.Sdk.Project.CustomType
                (Optional CustomTypeGen.Output)
                ( \(ct : Deps.Sdk.Project.CustomType) ->
                    Deps.Typeclasses.Classes.Alternative.optional
                      Sdk.Compiled.Type
                      Sdk.Compiled.alternative
                      CustomTypeGen.Output
                      (CustomTypeGen.run config ct)
                )
                input.customTypes

        let compiledTypes
            : Sdk.Compiled.Type (List CustomTypeGen.Output)
            = Sdk.Compiled.map
                (List (Optional CustomTypeGen.Output))
                (List CustomTypeGen.Output)
                (Deps.Prelude.List.unpackOptionals CustomTypeGen.Output)
                compiledTypes

        let files
            : Sdk.Compiled.Type (List Sdk.File.Type)
            = Sdk.Compiled.map2
                (List QueryGen.Output)
                (List CustomTypeGen.Output)
                (List Sdk.File.Type)
                (combineOutputs config input)
                compiledQueries
                compiledTypes

        in  files

in  Algebra.module Input Output run
