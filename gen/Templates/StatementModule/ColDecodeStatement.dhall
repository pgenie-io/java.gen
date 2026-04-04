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
      , jdbcGetter : Text
      }

in  Algebra.module
      Params
      ( \(p : Params) ->
          if    p.useCodec
          then  let elemSuffix =
                      if    p.elementIsOptional
                      then  ".stream().map(Optional::ofNullable).toList()"
                      else  ""

                in  if    p.isOptional
                    then  ''
                          ${p.fieldType} ${p.fieldName};
                          {
                              String ${p.fieldName}Str = rs.getString(${p.colIdx});
                              if (${p.fieldName}Str != null) {
                                  ${p.fieldName} = Optional.of(${p.codecRef}.decodeInTextFromString(${p.fieldName}Str)${elemSuffix});
                              } else {
                                  ${p.fieldName} = Optional.empty();
                              }
                          }''
                    else  if p.isNullable
                    then  ''
                          ${p.fieldType} ${p.fieldName};
                          {
                              String ${p.fieldName}Str = rs.getString(${p.colIdx});
                              if (${p.fieldName}Str != null) {
                                  ${p.fieldName} = ${p.codecRef}.decodeInTextFromString(${p.fieldName}Str)${elemSuffix};
                              }
                          }''
                    else  "${p.fieldType} ${p.fieldName} = ${p.codecRef}.decodeInTextFromString(rs.getString(${p.colIdx}))${elemSuffix};"
          else  if p.isDateType
          then  if    p.isOptional
                then  ''
                      ${p.fieldType} ${p.fieldName};
                      {
                          Date ${p.fieldName}Sql = rs.getDate(${p.colIdx});
                          if (${p.fieldName}Sql != null) {
                              ${p.fieldName} = Optional.of(${p.fieldName}Sql.toLocalDate());
                          } else {
                              ${p.fieldName} = Optional.empty();
                          }
                      }''
                else  if p.isNullable
                then  ''
                      LocalDate ${p.fieldName};
                      {
                          Date ${p.fieldName}Sql = rs.getDate(${p.colIdx});
                          if (${p.fieldName}Sql != null) {
                              ${p.fieldName} = ${p.fieldName}Sql.toLocalDate();
                          }
                      }''
                else  "LocalDate ${p.fieldName} = rs.getDate(${p.colIdx}).toLocalDate();"
          else  if p.isOptional
          then  if    p.isJdbcPrimitive
                then  "${p.fieldType} ${p.fieldName} = Optional.ofNullable((${p.boxedJavaType}) rs.getObject(${p.colIdx}));"
                else  "${p.fieldType} ${p.fieldName} = Optional.ofNullable(rs.${p.jdbcGetter}(${p.colIdx}));"
          else  if p.isNullable && p.isJdbcPrimitive
          then  "${p.fieldType} ${p.fieldName} = (${p.fieldType}) rs.getObject(${p.colIdx});"
          else  "${p.fieldType} ${p.fieldName} = rs.${p.jdbcGetter}(${p.colIdx});"
      )
