let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Typeclasses = Deps.Typeclasses

let Sdk = Deps.Sdk

let Lude = Deps.Lude

let Templates = ../Templates/package.dhall

let ResultModule = ./Result.dhall

let QueryFragmentsModule = ./QueryFragments.dhall

let Member = ./Member.dhall

let Input = Deps.Sdk.Project.Query

let Output =
      { statementModuleName : Text
      , statementModulePath : Text
      , statementModuleContents : Text
      , testModulePath : Text
      , testModuleContents : Text
      }

let render =
      \(config : Algebra.Config) ->
      \(input : Input) ->
      \(result : ResultModule.Output) ->
      \(fragments : QueryFragmentsModule.Output) ->
      \(params : List Member.Output) ->
        let statementModuleName = input.name.inPascalCase

        let statementModulePath = input.name.inPascalCase ++ ".java"

        let paramCastSuffixes =
              Deps.Prelude.List.map
                Member.Output
                Text
                (\(member : Member.Output) -> member.pgCastSuffix)
                params

        let sqlExp = fragments.mkSqlExp paramCastSuffixes

        let paramBindCode =
              let paramOccurrences =
                    Deps.Prelude.List.filterMap
                      Deps.Sdk.Project.QueryFragment
                      Natural
                      ( \(fragment : Deps.Sdk.Project.QueryFragment) ->
                          merge
                            { Sql = \(_ : Text) -> None Natural
                            , Var =
                                \(v : Deps.Sdk.Project.Var) -> Some v.paramIndex
                            }
                            fragment
                      )
                      input.fragments

              let indexedOccurrences =
                    Deps.Prelude.List.indexed Natural paramOccurrences

              in  Deps.Prelude.Text.concatSep
                    "\n"
                    ( Deps.Prelude.List.filterMap
                        { index : Natural, value : Natural }
                        Text
                        ( \(ip : { index : Natural, value : Natural }) ->
                            let idx = Natural/show (ip.index + 1)

                            let mParam =
                                  Deps.Prelude.List.index
                                    ip.value
                                    Member.Output
                                    params

                            in  merge
                                  { None = None Text
                                  , Some =
                                      \(p : Member.Output) ->
                                        Some
                                          ( Templates.ParamBindStatement.run
                                              { idx
                                              , fieldName = p.fieldName
                                              , codecRef = p.codecRef
                                              , isOptional = p.isOptional
                                              , elementIsOptional =
                                                  p.elementIsOptional
                                              , dims = p.dims
                                              }
                                          )
                                  }
                                  mParam
                        )
                        indexedOccurrences
                    )

        let hasResult =
              merge
                { Void = False
                , RowsAffected = True
                , Rows = \(_ : Deps.Sdk.Project.ResultRows) -> True
                }
                input.result

        let resultInfo = result statementModuleName

        let paramImports =
              List/fold
                Member.Output
                params
                ImportSet.Type
                ( \(param : Member.Output) ->
                  \(acc : ImportSet.Type) ->
                    ImportSet.combine param.imports acc
                )
                ImportSet.empty

        let extraImports = ImportSet.combine paramImports resultInfo.imports

        let paramFields =
              Deps.Prelude.List.map
                Member.Output
                Text
                ( \(member : Member.Output) ->
                    Templates.ParamField.run
                      { pgName = member.pgName
                      , fieldType = member.fieldType
                      , fieldName = member.fieldName
                      , isNullable = member.isNullable
                      }
                )
                params

        let isOptionalCardinality =
              merge
                { Void = False
                , RowsAffected = False
                , Rows =
                    \(rows : Deps.Sdk.Project.ResultRows) ->
                      merge
                        { Optional = True, Single = False, Multiple = False }
                        rows.cardinality
                }
                input.result

        let isMultipleCardinality =
              merge
                { Void = False
                , RowsAffected = False
                , Rows =
                    \(rows : Deps.Sdk.Project.ResultRows) ->
                      merge
                        { Optional = False, Single = False, Multiple = True }
                        rows.cardinality
                }
                input.result

        let statementModuleContents =
              Templates.StatementModule.run
                { packageName = config.packageName
                , typeName = statementModuleName
                , queryName = input.name.inSnakeCase
                , sqlDoc = fragments.docComment
                , sqlExp
                , paramBindCode
                , srcPath = input.srcPath
                , paramFields
                , typeDecls = resultInfo.typeDecls
                , statementImpl = resultInfo.statementImpl
                , statementTypeArg = resultInfo.statementTypeArg
                , extraImports
                , hasResultType = hasResult
                }

        let defaultArgs =
              Deps.Prelude.List.map
                Member.Output
                Text
                (\(m : Member.Output) -> m.testDefaultLiteral)
                params

        let testRandomArgs =
              Deps.Prelude.List.map
                Member.Output
                Text
                (\(m : Member.Output) -> m.testRandomLiteral)
                params

        let identityFieldNames =
              Deps.Prelude.List.map
                Member.Output
                Text
                (\(m : Member.Output) -> m.fieldName)
                params

        let testModulePath = input.name.inPascalCase ++ "IT.java"

        let testModuleContents =
              Templates.StatementTestModule.run
                { packageName = config.packageName
                , typeName = statementModuleName
                , defaultArgs
                , hasResult
                , resultNullable =
                        isOptionalCardinality
                    &&  Deps.Prelude.Bool.not config.useOptional
                , shouldTestIdentity = input.identity
                , identityFieldNames
                , testRandomArgs
                , isMultipleCardinality
                , isOptionalCardinality
                }

        in  { statementModuleName
            , statementModulePath
            , statementModuleContents
            , testModulePath
            , testModuleContents
            }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Lude.Compiled.nest
          Output
          input.srcPath
          ( Typeclasses.Classes.Applicative.map3
              Lude.Compiled.Type
              Lude.Compiled.applicative
              ResultModule.Output
              QueryFragmentsModule.Output
              (List Member.Output)
              Output
              (render config input)
              ( Lude.Compiled.nest
                  ResultModule.Output
                  "result"
                  (ResultModule.run config input.result)
              )
              ( Lude.Compiled.nest
                  QueryFragmentsModule.Output
                  "sql"
                  (QueryFragmentsModule.run config input.fragments)
              )
              ( Lude.Compiled.nest
                  (List Member.Output)
                  "params"
                  ( Typeclasses.Classes.Applicative.traverseList
                      Lude.Compiled.Type
                      Lude.Compiled.applicative
                      Deps.Sdk.Project.Member
                      Member.Output
                      (Member.run config)
                      input.params
                  )
              )
          )

in  Algebra.module Input Output run
