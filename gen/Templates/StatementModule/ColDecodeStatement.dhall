-- Renders a single result-set column decode statement.
-- colIdx: 1-based column index as a string (e.g. "1", "2").
-- Produces the statement(s) without any surrounding indentation; splice site must indent.
let Algebra = ../Algebra/package.dhall

let Params =
      { colIdx : Text
      , fieldName : Text
      , fieldType : Text
      , boxedJavaType : Text
      , useCodec : Bool
      , codecRef : Text
      , elementIsOptional : Bool
      , isOptional : Bool
      , isNullable : Bool
      , isDateType : Bool
      , isJdbcPrimitive : Bool
      , rowVarPresent : Bool
      , jdbcGetter : Text
      }

in  Algebra.module
      Params
      ( \(p : Params) ->
          let rowExpr = if p.rowVarPresent then "row" else "0"

          in  if    p.useCodec
              then  let elemSuffix =
                          if    p.elementIsOptional
                          then  ".stream().map(Optional::ofNullable).toList()"
                          else  ""

                    in  if    p.isOptional
                        then  "${p.fieldType} ${p.fieldName}Col = Optional.ofNullable(new JdbcCodec<>(${p.codecRef}).decodeNullable(rs, ${rowExpr}, ${p.colIdx})${elemSuffix});"
                        else  if p.isNullable
                        then  "${p.fieldType} ${p.fieldName}Col = new JdbcCodec<>(${p.codecRef}).decodeNullable(rs, ${rowExpr}, ${p.colIdx})${elemSuffix};"
                        else  "${p.fieldType} ${p.fieldName}Col = new JdbcCodec<>(${p.codecRef}).decodeNonNullable(rs, ${rowExpr}, ${p.colIdx})${elemSuffix};"
              else  if p.isDateType
              then  if    p.isOptional
                    then  ''
                          ${p.fieldType} ${p.fieldName}Col;
                          {
                              Date ${p.fieldName}ColBase = rs.getDate(${p.colIdx});
                              if (${p.fieldName}ColBase != null) {
                                  ${p.fieldName}Col = Optional.of(${p.fieldName}ColBase.toLocalDate());
                              } else {
                                  ${p.fieldName}Col = Optional.empty();
                              }
                          }''
                    else  if p.isNullable
                    then  ''
                          LocalDate ${p.fieldName}Col;
                          {
                              Date ${p.fieldName}ColBase = rs.getDate(${p.colIdx});
                              if (${p.fieldName}ColBase != null) {
                                  ${p.fieldName}Col = ${p.fieldName}ColBase.toLocalDate();
                              }
                          }''
                    else  "LocalDate ${p.fieldName}Col = rs.getDate(${p.colIdx}).toLocalDate();"
              else  if p.isOptional
              then  if    p.isJdbcPrimitive
                    then  "${p.fieldType} ${p.fieldName}Col = Optional.ofNullable((${p.boxedJavaType}) rs.getObject(${p.colIdx}));"
                    else  "${p.fieldType} ${p.fieldName}Col = Optional.ofNullable(rs.${p.jdbcGetter}(${p.colIdx}));"
              else  if p.isNullable && p.isJdbcPrimitive
              then  "${p.fieldType} ${p.fieldName}Col = (${p.fieldType}) rs.getObject(${p.colIdx});"
              else  "${p.fieldType} ${p.fieldName}Col = rs.${p.jdbcGetter}(${p.colIdx});"
      )
