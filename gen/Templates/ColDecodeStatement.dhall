-- Renders a single result-set column decode statement.
-- colIdx: 1-based column index as a string (e.g. "1", "2").
-- Produces the statement(s) without any surrounding indentation; splice site must indent.
let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Template.dhall

let Params =
      { colIdx : Text
      , varName : Text
      , fieldType : Text
      , codecRef : Text
      , dims : Natural
      , useOptional : Bool
      , isNullable : Bool
      , elementIsNullable : Bool
      , rowVarPresent : Bool
      }

in  Algebra.module
      Params
      ( \(p : Params) ->
          let rowExpr = if p.rowVarPresent then "row" else "0"

          let expression =
                if    p.isNullable
                then  if    p.useOptional
                      then  let suffix =
                                  if    p.elementIsNullable
                                  then  if    Deps.Prelude.Natural.equal
                                                p.dims
                                                0
                                        then  ""
                                        else  if Deps.Prelude.Natural.equal
                                                   p.dims
                                                   1
                                        then  ".map(list1 -> list1.stream().map(Optional::ofNullable).toList())"
                                        else  if Deps.Prelude.Natural.equal
                                                   p.dims
                                                   2
                                        then  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(Optional::ofNullable).toList()).toList())"
                                        else  if Deps.Prelude.Natural.equal
                                                   p.dims
                                                   3
                                        then  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(list3 -> list3.stream().map(Optional::ofNullable).toList()).toList()).toList())"
                                        else  if Deps.Prelude.Natural.equal
                                                   p.dims
                                                   4
                                        then  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(list3 -> list3.stream().map(list4 -> list4.stream().map(Optional::ofNullable).toList()).toList()).toList()).toList())"
                                        else  if Deps.Prelude.Natural.equal
                                                   p.dims
                                                   5
                                        then  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(list3 -> list3.stream().map(list4 -> list4.stream().map(list5 -> list5.stream().map(Optional::ofNullable).toList()).toList()).toList()).toList()).toList())"
                                        else  ".map(list1 -> list1.stream().map(list2 -> list2.stream().map(list3 -> list3.stream().map(list4 -> list4.stream().map(list5 -> list5.stream().map(list6 -> list6.stream().map(Optional::ofNullable).toList()).toList()).toList()).toList()).toList()).toList())"
                                  else  ""

                            in  "${p.codecRef}.decodeOptional(rs, ${rowExpr}, ${p.colIdx})${suffix}"
                      else  "${p.codecRef}.decodeNullable(rs, ${rowExpr}, ${p.colIdx})"
                else  "${p.codecRef}.decodeNonNullable(rs, ${rowExpr}, ${p.colIdx})"

          in  "${p.fieldType} ${p.varName} = ${expression};"
      )
