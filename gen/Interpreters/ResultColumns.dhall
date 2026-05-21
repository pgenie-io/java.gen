let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let ResultColumnsMember = ./ResultColumnsMember.dhall

let Templates = ../Templates/package.dhall

let Input = List Deps.Sdk.Project.Member

let Output =
      { columnFieldList : Text
      , decodeLinesWithRowVar : Text
      , decodeLinesWithoutRowVar : Text
      , columnNames : List Text
      , imports : ImportSet.Type
      , needsCustomTypeImport : Bool
      }

in  Algebra.module
      Input
      Output
      ( \(config : Algebra.Config) ->
        \(input : Input) ->
          let compiledColumns =
                Deps.Typeclasses.Classes.Applicative.traverseList
                  Deps.Lude.Compiled.Type
                  Deps.Lude.Compiled.applicative
                  Deps.Sdk.Project.Member
                  ResultColumnsMember.Output
                  (ResultColumnsMember.run config)
                  input

          in  Deps.Lude.Compiled.map
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
                            ImportSet.Type
                            ( \(col : ResultColumnsMember.Output) ->
                              \(acc : ImportSet.Type) ->
                                ImportSet.combine col.imports acc
                            )
                            ImportSet.empty

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
