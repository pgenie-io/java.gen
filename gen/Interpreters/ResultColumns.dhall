let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Member = ./ResultColumnsMember.dhall

let StatementModuleSub = ../Templates/StatementModule/package.dhall

let Input = List Deps.Sdk.Project.Member

let Output =
      { columnFieldList : Text
      , decodeLinesWithRowVar : Text
      , decodeLinesWithoutRowVar : Text
      , columnNames : List Text
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
                  Member.Output
                  (Member.run config)
                  input

          in  Deps.Sdk.Compiled.map
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

                    in  { columnFieldList
                        , decodeLinesWithRowVar = mkDecodeLines True
                        , decodeLinesWithoutRowVar = mkDecodeLines False
                        , columnNames
                        }
                )
                compiledColumns
      )
