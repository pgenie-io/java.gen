let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Contract = ../Deps/Contract.dhall

let ImportSet = ../Structures/ImportSet.dhall

let ResultColumns = ./ResultColumns.dhall

let Templates = ../Templates/package.dhall

let Config = { useOptional : Bool }

let Input = Contract.ResultRows

let Output =
      Text ->
        { statementImpl : Text
        , typeDecls : Text
        , statementTypeArg : Text
        , imports : ImportSet.Type
        }

let run =
      \(config : Config) ->
      \(input : Input) ->
        let compiledColumns =
              ResultColumns.run
                config
                (Prelude.NonEmpty.toList Contract.Member input.columns)

        in  Lude.Compiled.map
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
                        , resultTypeName = "${typeNameBase}.Result"
                        }

                  let singleResult =
                        { typeDecls =
                            Templates.SingleResultTypeDecls.run
                              { typeNameBase
                              , columnFieldList = cols.columnFieldList
                              , rowTypeName = "Result"
                              }
                        , decodeMethod =
                            Templates.SingleDecodeMethod.run
                              { decodeLines = cols.decodeLinesWithoutRowVar
                              , columnNames = cols.columnNames
                              }
                        , resultTypeName = "${typeNameBase}.Result"
                        }

                  let optionalResult =
                        if    config.useOptional
                        then  { typeDecls =
                                  Templates.SingleResultTypeDecls.run
                                    { typeNameBase
                                    , columnFieldList = cols.columnFieldList
                                    , rowTypeName = "ResultRow"
                                    }
                              , decodeMethod =
                                  Templates.OptionalDecodeMethod.run
                                    { decodeLines =
                                        cols.decodeLinesWithoutRowVar
                                    , columnNames = cols.columnNames
                                    , useOptional = True
                                    }
                              , resultTypeName =
                                  "Optional<${typeNameBase}.ResultRow>"
                              }
                        else  { typeDecls =
                                  Templates.SingleResultTypeDecls.run
                                    { typeNameBase
                                    , columnFieldList = cols.columnFieldList
                                    , rowTypeName = "Result"
                                    }
                              , decodeMethod =
                                  Templates.OptionalDecodeMethod.run
                                    { decodeLines =
                                        cols.decodeLinesWithoutRowVar
                                    , columnNames = cols.columnNames
                                    , useOptional = False
                                    }
                              , resultTypeName = "${typeNameBase}.Result"
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
                      , imports = cols.imports
                      }
              )
              compiledColumns

in  Sdk.Sigs.interpreter Config Input Output run
