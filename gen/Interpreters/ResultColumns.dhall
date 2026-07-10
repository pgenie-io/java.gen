let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Contract = ../Deps/Contract.dhall

let Typeclasses = ../Deps/Typeclasses.dhall

let ImportSet = ../Structures/ImportSet.dhall

let ResolvedTarget = ../ResolvedTarget.dhall

let Member = ./Member.dhall

let Templates = ../Templates/package.dhall

let Input = List Contract.Member

let Output =
      { columnFieldList : Text
      , decodeLinesWithRowVar : Text
      , decodeLinesWithoutRowVar : Text
      , columnNames : List Text
      , imports : ImportSet.Type
      }

in  Sdk.Sigs.Interpreter.module
      ResolvedTarget.Type
      Input
      Output
      ( \(config : ResolvedTarget.Type) ->
        \(input : Input) ->
          let compiledColumns =
                Typeclasses.Classes.Applicative.traverseList
                  Lude.Compiled.Type
                  Lude.Compiled.applicative
                  Contract.Member
                  Member.Output
                  (Member.run config)
                  input

          in  Lude.Compiled.map
                (List Member.Output)
                Output
                ( \(columns : List Member.Output) ->
                    let indexedColumns =
                          Prelude.List.indexed Member.Output columns

                    let columnFieldList =
                          Prelude.Text.concatMapSep
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
                            Prelude.Text.concatMapSep
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
                          Prelude.List.map
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
