let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let ResultColumns = ./ResultColumns.dhall

let Templates = ../Templates/package.dhall

let Input = Deps.Sdk.Project.ResultRows

let Output =
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
                \(typeNameBase : Text) ->
                  let multipleResult =
                        { typeDecls =
                            Templates.MultipleResultTypeDecls.run
                              { typeNameBase
                              , columnFieldList = cols.columnFieldList
                              }
                        , decodeMethod =
                            Templates.MultipleDecodeMethod.run
                              { decodeLines = cols.decodeLinesWithRowVar
                              , columnNames = cols.columnNames
                              }
                        , resultTypeName = "${typeNameBase}.Output"
                        }

                  let singleResult =
                        { typeDecls =
                            Templates.SingleResultTypeDecls.run
                              { typeNameBase
                              , columnFieldList = cols.columnFieldList
                              , rowTypeName = "Output"
                              }
                        , decodeMethod =
                            Templates.SingleDecodeMethod.run
                              { decodeLines = cols.decodeLinesWithoutRowVar
                              , columnNames = cols.columnNames
                              }
                        , resultTypeName = "${typeNameBase}.Output"
                        }

                  let optionalResult =
                        if    config.useOptional
                        then  { typeDecls =
                                  Templates.SingleResultTypeDecls.run
                                    { typeNameBase
                                    , columnFieldList = cols.columnFieldList
                                    , rowTypeName = "OutputRow"
                                    }
                              , decodeMethod =
                                  Templates.OptionalDecodeMethod.run
                                    { decodeLines =
                                        cols.decodeLinesWithoutRowVar
                                    , columnNames = cols.columnNames
                                    , useOptional = True
                                    }
                              , resultTypeName =
                                  "Optional<${typeNameBase}.OutputRow>"
                              }
                        else  { typeDecls =
                                  Templates.SingleResultTypeDecls.run
                                    { typeNameBase
                                    , columnFieldList = cols.columnFieldList
                                    , rowTypeName = "Output"
                                    }
                              , decodeMethod =
                                  Templates.OptionalDecodeMethod.run
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
                          Templates.StatementImplWithResult.run
                            { decodeMethod = resolved.decodeMethod
                            , resultTypeName = resolved.resultTypeName
                            }
                      , typeDecls = resolved.typeDecls
                      , statementTypeArg = resolved.resultTypeName
                      }
              )
              compiledColumns

in  Algebra.module Input Output run
