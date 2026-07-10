let ImportSet = ../Structures/ImportSet.dhall

let Typeclasses = ../Deps/Typeclasses.dhall

let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Contract = ../Deps/Contract.dhall

let Templates = ../Templates/package.dhall

let ResultModule = ./Result.dhall

let QueryFragmentsModule = ./QueryFragments.dhall

let Member = ./Member.dhall

let Config = { packageName : Text, useOptional : Bool }

let Input = Contract.Query

let Output =
      { statementModuleName : Text
      , statementModulePath : Text
      , statementModuleContents : Text
      , testModulePath : Text
      , testModuleContents : Text
      }

let render =
      \(config : Config) ->
      \(input : Input) ->
      \(result : ResultModule.Output) ->
      \(fragments : QueryFragmentsModule.Output) ->
      \(params : List Member.Output) ->
        let statementModuleName = input.name.inPascalCase

        let statementModulePath = input.name.inPascalCase ++ ".java"

        let paramCastSuffixes =
              Prelude.List.map
                Member.Output
                Text
                (\(member : Member.Output) -> member.pgCastSuffix)
                params

        let sqlExp = fragments.mkSqlExp paramCastSuffixes

        let paramBindCode =
              let paramOccurrences =
                    Prelude.List.filterMap
                      Contract.QueryFragment
                      Natural
                      ( \(fragment : Contract.QueryFragment) ->
                          merge
                            { Sql = \(_ : Text) -> None Natural
                            , Var = \(v : Contract.Var) -> Some v.paramIndex
                            }
                            fragment
                      )
                      input.fragments

              let indexedOccurrences =
                    Prelude.List.indexed Natural paramOccurrences

              in  Prelude.Text.concatSep
                    "\n"
                    ( Prelude.List.filterMap
                        { index : Natural, value : Natural }
                        Text
                        ( \(ip : { index : Natural, value : Natural }) ->
                            let idx = Natural/show (ip.index + 1)

                            let mParam =
                                  Prelude.List.index
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
                , Rows = \(_ : Contract.ResultRows) -> True
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
              Prelude.List.map
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
                    \(rows : Contract.ResultRows) ->
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
                    \(rows : Contract.ResultRows) ->
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
              Prelude.List.map
                Member.Output
                Text
                (\(m : Member.Output) -> m.testDefaultLiteral)
                params

        let testRandomArgs =
              Prelude.List.map
                Member.Output
                Text
                (\(m : Member.Output) -> m.testRandomLiteral)
                params

        let identityFieldNames =
              Prelude.List.map
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
                    isOptionalCardinality && Prelude.Bool.not config.useOptional
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
      \(config : Config) ->
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
                  (ResultModule.run config.{ useOptional } input.result)
              )
              ( Lude.Compiled.nest
                  QueryFragmentsModule.Output
                  "sql"
                  (QueryFragmentsModule.run {=} input.fragments)
              )
              ( Lude.Compiled.nest
                  (List Member.Output)
                  "params"
                  ( Typeclasses.Classes.Applicative.traverseList
                      Lude.Compiled.Type
                      Lude.Compiled.applicative
                      Contract.Member
                      Member.Output
                      (Member.run config.{ useOptional })
                      input.params
                  )
              )
          )

in  Sdk.Sigs.Interpreter.module Config Input Output run
