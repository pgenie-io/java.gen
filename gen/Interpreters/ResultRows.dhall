let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Member = ./Member.dhall

let StatementModuleSub = ../Templates/StatementModule/package.dhall

let Input = Deps.Sdk.Project.ResultRows

let ExtraCtx = { sqlExp : Text, paramBindCode : Text }

let Output = ExtraCtx -> Text -> { statementImpl : Text, typeDecls : Text }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let compiledColumns =
              Deps.Typeclasses.Classes.Applicative.traverseList
                Deps.Sdk.Compiled.Type
                Deps.Sdk.Compiled.applicative
                Deps.Sdk.Project.Member
                Member.Output
                (Member.run config)
                ( Deps.Prelude.NonEmpty.toList
                    Deps.Sdk.Project.Member
                    input.columns
                )

        in  Deps.Sdk.Compiled.flatMap
              (List Member.Output)
              Output
              ( \(columns : List Member.Output) ->
                  let hasCodecDecode =
                        Deps.Prelude.List.any
                          Member.Output
                          (\(col : Member.Output) -> col.useCodec)
                          columns

                  let indexedColumns =
                        Deps.Prelude.List.indexed Member.Output columns

                  let columnFieldList =
                        Deps.Prelude.Text.concatMapSep
                          ''
                          ,
                          ''
                          { index : Natural, value : Member.Output }
                          ( \ ( ic
                              : { index : Natural, value : Member.Output }
                              ) ->
                              StatementModuleSub.ResultColumnField.run
                                { pgName = ic.value.pgName
                                , fieldType = ic.value.fieldType
                                , fieldName = ic.value.fieldName
                                , isNullable = ic.value.isNullable
                                }
                          )
                          indexedColumns

                  let mkDecodeExpr =
                        \(ic : { index : Natural, value : Member.Output }) ->
                          StatementModuleSub.ColDecodeStatement.run
                            { colIdx = Natural/show (ic.index + 1)
                            , fieldName = ic.value.fieldName
                            , fieldType = ic.value.fieldType
                            , boxedJavaType = ic.value.boxedJavaType
                            , useCodec = ic.value.useCodec
                            , codecRef = ic.value.codecRef
                            , elementIsOptional = ic.value.elementIsOptional
                            , isOptional = ic.value.isOptional
                            , isNullable = ic.value.isNullable
                            , isDateType = ic.value.isDateType
                            , isJdbcPrimitive = ic.value.isJdbcPrimitive
                            , jdbcGetter = ic.value.jdbcGetter
                            }

                  let decodeLines =
                        Deps.Prelude.Text.concatMapSep
                          "\n"
                          { index : Natural, value : Member.Output }
                          mkDecodeExpr
                          indexedColumns

                  let varRefs =
                        Deps.Prelude.Text.concatMapSep
                          ", "
                          Member.Output
                          (\(col : Member.Output) -> col.fieldName)
                          columns

                  let returnBody =
                        StatementModuleSub.DecodeBody.run
                          { hasCodecDecode
                          , decodeLines
                          , finalStatement = "return new Output(${varRefs});"
                          }

                  in  Deps.Sdk.Compiled.ok
                        Output
                        ( \(ctx : ExtraCtx) ->
                          \(typeNameBase : Text) ->
                            let multipleResult =
                                  { typeDecls =
                                      StatementModuleSub.MultipleResultTypeDecls.run
                                        { typeNameBase, columnFieldList }
                                  , decodeMethod =
                                      StatementModuleSub.MultipleDecodeMethod.run
                                        { hasCodecDecode, decodeLines, varRefs }
                                  , resultTypeName = "${typeNameBase}.Output"
                                  }

                            let singleResult =
                                  { typeDecls =
                                      StatementModuleSub.SingleResultTypeDecls.run
                                        { typeNameBase, columnFieldList }
                                  , decodeMethod =
                                      StatementModuleSub.SingleDecodeMethod.run
                                        { decodeBody = returnBody }
                                  , resultTypeName = "${typeNameBase}.Output"
                                  }

                            let optionalResult =
                                  { typeDecls = singleResult.typeDecls
                                  , decodeMethod =
                                      StatementModuleSub.OptionalDecodeMethod.run
                                        { decodeBody = returnBody }
                                  , resultTypeName = "${typeNameBase}.Output"
                                  }

                            let resolved =
                                  merge
                                    { Optional = optionalResult
                                    , Single = singleResult
                                    , Multiple = multipleResult
                                    }
                                    input.cardinality

                            in  { statementImpl =
                                    StatementModuleSub.StatementImplWithResult.run
                                      { sqlExp = ctx.sqlExp
                                      , paramBindCode = ctx.paramBindCode
                                      , decodeMethod = resolved.decodeMethod
                                      , resultTypeName = resolved.resultTypeName
                                      }
                                , typeDecls = resolved.typeDecls
                                }
                        )
              )
              compiledColumns

in  Algebra.module Input Output run
