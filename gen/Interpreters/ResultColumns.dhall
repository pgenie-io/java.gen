let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Member = ./Member.dhall

let Templates = ../Templates/package.dhall

let Input = List Deps.Sdk.Project.Member

let Output =
      { columnFieldList : Text
      , decodeLinesWithRowVar : Text
      , decodeLinesWithoutRowVar : Text
      , columnNames : List Text
      , imports : ImportSet.Type
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
                  Member.Output
                  (Member.run config)
                  input

          in  Deps.Lude.Compiled.map
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
                                ic.value.columnField
                            )
                            indexedColumns

                    let mkDecodeLines =
                          \(rowVarPresent : Bool) ->
                            Deps.Prelude.Text.concatMapSep
                              "\n"
                              { index : Natural, value : Member.Output }
                              ( \ ( ic
                                  : { index : Natural, value : Member.Output }
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
                            Member.Output
                            Text
                            (\(col : Member.Output) -> col.fieldName)
                            columns

                    let imports =
                          List/fold
                            Member.Output
                            columns
                            ImportSet.Type
                            ( \(col : Member.Output) ->
                              \(acc : ImportSet.Type) ->
                                ImportSet.combine col.imports acc
                            )
                            ImportSet.empty

                    in  { columnFieldList
                        , decodeLinesWithRowVar = mkDecodeLines True
                        , decodeLinesWithoutRowVar = mkDecodeLines False
                        , columnNames
                        , imports
                        }
                )
                compiledColumns
      )
