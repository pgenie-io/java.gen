let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Member = ./Member.dhall

let StatementModuleSub = ../Templates/StatementModule/package.dhall

let Input = Deps.Sdk.Project.ResultRows

let ExtraCtx = { sqlExp : Text, paramBindCode : Text }

let Output = ExtraCtx -> Text -> { statementImpl : Text, typeDecls : Text, statementTypeArg : Text }

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

                  let decodeLines =
                        \(rowVarPresent : Bool) ->
                          Deps.Prelude.Text.concatMapSep
                            "\n"
                            { index : Natural, value : Member.Output }
                            ( \ ( ic
                                : { index : Natural, value : Member.Output }
                                ) ->
                                StatementModuleSub.ColDecodeStatement.run
                                  { colIdx = Natural/show (ic.index + 1)
                                  , fieldName = ic.value.fieldName
                                  , fieldType = ic.value.fieldType
                                  , boxedJavaType = ic.value.boxedJavaType
                                  , useCodec = ic.value.useCodec
                                  , codecRef = ic.value.codecRef
                                  , elementIsOptional =
                                      ic.value.elementIsOptional
                                  , isOptional = ic.value.isOptional
                                  , isNullable = ic.value.isNullable
                                  , isDateType = ic.value.isDateType
                                  , isJdbcPrimitive = ic.value.isJdbcPrimitive
                                  , jdbcGetter = ic.value.jdbcGetter
                                  , rowVarPresent
                                  }
                            )
                            indexedColumns

                  let columnNames =
                        Deps.Prelude.List.map
                          Member.Output
                          Text
                          (\(col : Member.Output) -> col.fieldName)
                          columns

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
                                        { decodeLines = decodeLines True
                                        , columnNames
                                        }
                                  , resultTypeName = "${typeNameBase}.Output"
                                  }

                            let singleResult =
                                  { typeDecls =
                                      StatementModuleSub.SingleResultTypeDecls.run
                                        { typeNameBase
                                        , columnFieldList
                                        , rowTypeName = "Output"
                                        }
                                  , decodeMethod =
                                      StatementModuleSub.SingleDecodeMethod.run
                                        { decodeLines = decodeLines False
                                        , columnNames
                                        }
                                  , resultTypeName = "${typeNameBase}.Output"
                                  }

                            let optionalResult =
                                  if config.useOptional
                                  then
                                    { typeDecls =
                                        StatementModuleSub.SingleResultTypeDecls.run
                                          { typeNameBase
                                          , columnFieldList
                                          , rowTypeName = "OutputRow"
                                          }
                                    , decodeMethod =
                                        StatementModuleSub.OptionalDecodeMethod.run
                                          { decodeLines = decodeLines False
                                          , columnNames
                                          , useOptional = True
                                          }
                                    , resultTypeName = "Optional<${typeNameBase}.OutputRow>"
                                    }
                                  else
                                    { typeDecls =
                                        StatementModuleSub.SingleResultTypeDecls.run
                                          { typeNameBase
                                          , columnFieldList
                                          , rowTypeName = "Output"
                                          }
                                    , decodeMethod =
                                        StatementModuleSub.OptionalDecodeMethod.run
                                          { decodeLines = decodeLines False
                                          , columnNames
                                          , useOptional = False
                                          }
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
                                , statementTypeArg = resolved.resultTypeName
                                }
                        )
              )
              compiledColumns

in  Algebra.module Input Output run
