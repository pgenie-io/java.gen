let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let ResultColumnsMember = ./ResultColumnsMember.dhall

let Templates = ../Templates/package.dhall

let Input = List Deps.Sdk.Project.Member

let Output =
      { columnFieldList : Text
      , decodeLinesWithRowVar : Text
      , decodeLinesWithoutRowVar : Text
      , columnNames : List Text
      , imports : List Text
      , needsCustomTypeImport : Bool
      }

in  Algebra.module
      Input
      Output
      ( \(config : Algebra.Config) ->
        \(input : Input) ->
          let compiledColumns =
                Deps.Typeclasses.Classes.Applicative.traverseList
                  Deps.Sdk.Compiled.Type
                  Deps.Sdk.Compiled.applicative
                  Deps.Sdk.Project.Member
                  ResultColumnsMember.Output
                  (ResultColumnsMember.run config)
                  input

          in  Deps.Sdk.Compiled.map
                (List ResultColumnsMember.Output)
                Output
                ( \(columns : List ResultColumnsMember.Output) ->
                    let indexedColumns =
                          Deps.Prelude.List.indexed
                            ResultColumnsMember.Output
                            columns

                    let columnFieldList =
                          Deps.Prelude.Text.concatMapSep
                            ''
                            ,
                            ''
                            { index : Natural
                            , value : ResultColumnsMember.Output
                            }
                            ( \ ( ic
                                : { index : Natural
                                  , value : ResultColumnsMember.Output
                                  }
                                ) ->
                                ic.value.columnField
                            )
                            indexedColumns

                    let mkDecodeLines =
                          \(rowVarPresent : Bool) ->
                            Deps.Prelude.Text.concatMapSep
                              "\n"
                              { index : Natural
                              , value : ResultColumnsMember.Output
                              }
                              ( \ ( ic
                                  : { index : Natural
                                    , value : ResultColumnsMember.Output
                                    }
                                  ) ->
                                  Templates.ColDecodeStatement.run
                                    { colIdx = Natural/show (ic.index + 1)
                                    , varName = "${ic.value.fieldName}Col"
                                    , fieldType = ic.value.fieldType
                                    , codecRef = ic.value.codecRef
                                    , dims = ic.value.dims
                                    , useOptional = config.useOptional
                                    , isNullable = ic.value.isNullable
                                    , elementIsNullable =
                                        ic.value.elementIsNullable
                                    , rowVarPresent
                                    }
                              )
                              indexedColumns

                    let columnNames =
                          Deps.Prelude.List.map
                            ResultColumnsMember.Output
                            Text
                            ( \(col : ResultColumnsMember.Output) ->
                                col.fieldName
                            )
                            columns

                    let imports =
                          List/fold
                            ResultColumnsMember.Output
                            columns
                            (List Text)
                            ( \(col : ResultColumnsMember.Output) ->
                              \(acc : List Text) ->
                                col.imports # acc
                            )
                            ([] : List Text)

                    let needsCustomTypeImport =
                          Deps.Prelude.List.any
                            ResultColumnsMember.Output
                            ( \(col : ResultColumnsMember.Output) ->
                                col.needsCustomTypeImport
                            )
                            columns

                    in  { columnFieldList
                        , decodeLinesWithRowVar = mkDecodeLines True
                        , decodeLinesWithoutRowVar = mkDecodeLines False
                        , columnNames
                        , imports
                        , needsCustomTypeImport
                        }
                )
                compiledColumns
      )
