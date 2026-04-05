let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Lude = Deps.Lude

let Typeclasses = Deps.Typeclasses

let Sdk = Deps.Sdk

let Templates = ../Templates/package.dhall

let StatementModuleSub = ../Templates/StatementModule/package.dhall

let ResultModule = ./Result.dhall

let QueryFragmentsModule = ./QueryFragments.dhall

let MemberModule = ./Member.dhall

let Input = Deps.Sdk.Project.Query

let Output =
      { statementModuleName : Text
      , statementModulePath : Text
      , statementModuleContents : Text
      , testModulePath : Text
      , testModuleContents : Text
      }

let mkParamBindCode =
      \(params : List MemberModule.Output) ->
      \(fragments : Deps.Sdk.Project.QueryFragments) ->
        let paramOccurrences =
              Deps.Prelude.List.filterMap
                Deps.Sdk.Project.QueryFragment
                Natural
                ( \(fragment : Deps.Sdk.Project.QueryFragment) ->
                    merge
                      { Sql = \(_ : Text) -> None Natural
                      , Var = \(v : Deps.Sdk.Project.Var) -> Some v.paramIndex
                      }
                      fragment
                )
                fragments

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
                              MemberModule.Output
                              params

                      in  merge
                            { None = None Text
                            , Some =
                                \(p : MemberModule.Output) ->
                                  Some
                                    ( StatementModuleSub.ParamBindStatement.run
                                        { idx
                                        , fieldName = p.fieldName
                                        , useCodec = p.useCodec
                                        , codecRef = p.codecRef
                                        , isDateType = p.isDateType
                                        , isOptional = p.isOptional
                                        , isNullable = p.isNullable
                                        , jdbcSetter = p.jdbcSetter
                                        , sqlTypesConstant = p.sqlTypesConstant
                                        }
                                    )
                            }
                            mParam
                  )
                  indexedOccurrences
              )

let render =
      \(config : Algebra.Config) ->
      \(input : Input) ->
      \(result : ResultModule.Output) ->
      \(fragments : QueryFragmentsModule.Output) ->
      \(params : List MemberModule.Output) ->
        let statementModuleName = Deps.CodegenKit.Name.toTextInPascal input.name

        let statementModulePath =
              Deps.CodegenKit.Name.toTextInPascal input.name ++ ".java"

        let paramCastSuffixes =
              Deps.Prelude.List.map
                MemberModule.Output
                Text
                (\(member : MemberModule.Output) -> member.pgCastSuffix)
                params

        let sqlExp = fragments.mkSqlExp paramCastSuffixes

        let paramBindCode = mkParamBindCode params input.fragments

        let hasResult =
              Deps.Prelude.Optional.fold
                Deps.Sdk.Project.ResultRows
                input.result
                Bool
                (\(_ : Deps.Sdk.Project.ResultRows) -> True)
                False

        let resultInfo = result { sqlExp, paramBindCode } statementModuleName

        let paramFields =
              Deps.Prelude.List.map
                MemberModule.Output
                { pgName : Text
                , fieldType : Text
                , fieldName : Text
                , isNullable : Bool
                }
                ( \(member : MemberModule.Output) ->
                    { pgName = member.pgName
                    , fieldType = member.fieldType
                    , fieldName = member.fieldName
                    , isNullable = member.isNullable
                    }
                )
                params

        let hasCodecParam =
              Deps.Prelude.List.any
                MemberModule.Output
                (\(m : MemberModule.Output) -> m.useCodec)
                params

        let hasDateParam =
              Deps.Prelude.List.any
                MemberModule.Output
                (\(m : MemberModule.Output) -> m.isDateType)
                params

        let hasNullableJdbcParam =
              Deps.Prelude.List.any
                MemberModule.Output
                ( \(m : MemberModule.Output) ->
                    m.isNullable && m.useCodec == False
                )
                params

        let hasOptionalParam =
              Deps.Prelude.List.any
                MemberModule.Output
                (\(m : MemberModule.Output) -> m.isOptional)
                params

        let hasOptionalResult =
              Deps.Prelude.Optional.fold
                Deps.Sdk.Project.ResultRows
                input.result
                Bool
                ( \(rows : Deps.Sdk.Project.ResultRows) ->
                        config.useOptional
                    &&  Deps.Prelude.List.any
                          Deps.Sdk.Project.Member
                          ( \(m : Deps.Sdk.Project.Member) ->
                                  m.isNullable
                              ||  Deps.Prelude.Optional.fold
                                    Deps.Sdk.Project.ArraySettings
                                    m.value.arraySettings
                                    Bool
                                    ( \(arr : Deps.Sdk.Project.ArraySettings) ->
                                        arr.elementIsNullable
                                    )
                                    False
                          )
                          ( Deps.Prelude.NonEmpty.toList
                              Deps.Sdk.Project.Member
                              rows.columns
                          )
                )
                False

        let isOptionalCardinality =
              Deps.Prelude.Optional.fold
                Deps.Sdk.Project.ResultRows
                input.result
                Bool
                ( \(rows : Deps.Sdk.Project.ResultRows) ->
                    merge
                      { Optional = True, Single = False, Multiple = False }
                      rows.cardinality
                )
                False

        let hasOptionalResultType =
              config.useOptional && isOptionalCardinality

        let hasCodecResult =
              Deps.Prelude.Optional.fold
                Deps.Sdk.Project.ResultRows
                input.result
                Bool
                (\(rows : Deps.Sdk.Project.ResultRows) -> True)
                False

        let needsArrayListImport =
              Deps.Prelude.Optional.fold
                Deps.Sdk.Project.ResultRows
                input.result
                Bool
                ( \(rows : Deps.Sdk.Project.ResultRows) ->
                    merge
                      { Optional = False, Single = False, Multiple = True }
                      rows.cardinality
                )
                False

        let statementModuleContents =
              Templates.StatementModule.run
                { packageName = config.packageName
                , typeName = statementModuleName
                , queryName = Deps.CodegenKit.Name.toTextInSnake input.name
                , sqlDoc = fragments.docComment
                , srcPath = input.srcPath
                , paramFields
                , typeDecls = resultInfo.typeDecls
                , statementImpl = resultInfo.statementImpl
                , statementTypeArg = resultInfo.statementTypeArg
                , hasCodecParam
                , hasDateParam
                , hasNullableJdbcParam
                , needsArrayListImport
                , hasResultType = hasResult
                , hasDateResult = hasResult
                , hasCodecResult = hasResult
                , hasOptionalFields = hasOptionalParam || hasOptionalResult || hasOptionalResultType
                }

        let defaultArgs =
              Deps.Prelude.List.map
                MemberModule.Output
                Text
                (\(m : MemberModule.Output) -> m.testDefaultLiteral)
                params

        let testModulePath =
              Deps.CodegenKit.Name.toTextInPascal input.name ++ "IT.java"

        let testModuleContents =
              Templates.StatementTestModule.run
                { packageName = config.packageName
                , typeName = statementModuleName
                , defaultArgs
                , hasResult
                , resultNullable = isOptionalCardinality && Deps.Prelude.Bool.not config.useOptional
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
        Sdk.Compiled.nest
          Output
          input.srcPath
          ( Typeclasses.Classes.Applicative.map3
              Sdk.Compiled.Type
              Sdk.Compiled.applicative
              ResultModule.Output
              QueryFragmentsModule.Output
              (List MemberModule.Output)
              Output
              (render config input)
              ( Sdk.Compiled.nest
                  ResultModule.Output
                  "result"
                  (ResultModule.run config input.result)
              )
              ( Sdk.Compiled.nest
                  QueryFragmentsModule.Output
                  "sql"
                  (QueryFragmentsModule.run config input.fragments)
              )
              ( Sdk.Compiled.nest
                  (List MemberModule.Output)
                  "params"
                  ( Typeclasses.Classes.Applicative.traverseList
                      Sdk.Compiled.Type
                      Sdk.Compiled.applicative
                      Deps.Sdk.Project.Member
                      MemberModule.Output
                      (MemberModule.run config)
                      input.params
                  )
              )
          )

in  Algebra.module Input Output run
