let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let ResultColumns = ./ResultColumns.dhall

let StatementModuleSub = ../Templates/StatementModule/package.dhall

let Input = Deps.Sdk.Project.ResultRows

let ExtraCtx = { sqlExp : Text, paramBindCode : Text }

let Output =
      ExtraCtx ->
      Text ->
        { statementImpl : Text, typeDecls : Text, statementTypeArg : Text }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let compiledColumns =
              ResultColumns.run
                config
                ( Deps.Prelude.NonEmpty.toList
                    Deps.Sdk.Project.Member
                    input.columns
                )

        in  Deps.Sdk.Compiled.map
              ResultColumns.Output
              Output
              ( \(cols : ResultColumns.Output) ->
                \(ctx : ExtraCtx) ->
                \(typeNameBase : Text) ->
                  let multipleResult =
                        { typeDecls =
                            StatementModuleSub.MultipleResultTypeDecls.run
                              { typeNameBase
                              , columnFieldList = cols.columnFieldList
                              }
                        , decodeMethod =
                            StatementModuleSub.MultipleDecodeMethod.run
                              { decodeLines = cols.decodeLinesWithRowVar
                              , columnNames = cols.columnNames
                              }
                        , resultTypeName = "${typeNameBase}.Output"
                        }

                  let singleResult =
                        { typeDecls =
                            StatementModuleSub.SingleResultTypeDecls.run
                              { typeNameBase
                              , columnFieldList = cols.columnFieldList
                              , rowTypeName = "Output"
                              }
                        , decodeMethod =
                            StatementModuleSub.SingleDecodeMethod.run
                              { decodeLines = cols.decodeLinesWithoutRowVar
                              , columnNames = cols.columnNames
                              }
                        , resultTypeName = "${typeNameBase}.Output"
                        }

                  let optionalResult =
                        if    config.useOptional
                        then  { typeDecls =
                                  StatementModuleSub.SingleResultTypeDecls.run
                                    { typeNameBase
                                    , columnFieldList = cols.columnFieldList
                                    , rowTypeName = "OutputRow"
                                    }
                              , decodeMethod =
                                  StatementModuleSub.OptionalDecodeMethod.run
                                    { decodeLines =
                                        cols.decodeLinesWithoutRowVar
                                    , columnNames = cols.columnNames
                                    , useOptional = True
                                    }
                              , resultTypeName =
                                  "Optional<${typeNameBase}.OutputRow>"
                              }
                        else  { typeDecls =
                                  StatementModuleSub.SingleResultTypeDecls.run
                                    { typeNameBase
                                    , columnFieldList = cols.columnFieldList
                                    , rowTypeName = "Output"
                                    }
                              , decodeMethod =
                                  StatementModuleSub.OptionalDecodeMethod.run
                                    { decodeLines =
                                        cols.decodeLinesWithoutRowVar
                                    , columnNames = cols.columnNames
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
              compiledColumns

in  Algebra.module Input Output run
