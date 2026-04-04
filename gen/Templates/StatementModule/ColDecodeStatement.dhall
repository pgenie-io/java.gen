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
                          String ${p.fieldName}Str = rs.getString(${p.colIdx});
                          ${p.fieldType} ${p.fieldName} = Optional.ofNullable(${p.fieldName}Str != null ? ${p.codecRef}.decodeInTextFromString(${p.fieldName}Str)${elemSuffix} : null);''
                    else  if p.isNullable
                    then  ''
                          String ${p.fieldName}Str = rs.getString(${p.colIdx});
                          ${p.fieldType} ${p.fieldName} = ${p.fieldName}Str != null ? ${p.codecRef}.decodeInTextFromString(${p.fieldName}Str)${elemSuffix} : null;''
                    else  "${p.fieldType} ${p.fieldName} = ${p.codecRef}.decodeInTextFromString(rs.getString(${p.colIdx}))${elemSuffix};"
          else  if p.isDateType
          then  if    p.isOptional
                then  ''
                      Date ${p.fieldName}Sql = rs.getDate(${p.colIdx});
                      ${p.fieldType} ${p.fieldName} = Optional.ofNullable(${p.fieldName}Sql != null ? ${p.fieldName}Sql.toLocalDate() : null);''
                else  if p.isNullable
                then  ''
                      Date ${p.fieldName}Sql = rs.getDate(${p.colIdx});
                      LocalDate ${p.fieldName} = ${p.fieldName}Sql != null ? ${p.fieldName}Sql.toLocalDate() : null;''
                else  "LocalDate ${p.fieldName} = rs.getDate(${p.colIdx}).toLocalDate();"
          else  if p.isOptional
          then  if    p.isJdbcPrimitive
                then  "${p.fieldType} ${p.fieldName} = Optional.ofNullable((${p.boxedJavaType}) rs.getObject(${p.colIdx}));"
                else  "${p.fieldType} ${p.fieldName} = Optional.ofNullable(rs.${p.jdbcGetter}(${p.colIdx}));"
          else  if p.isNullable && p.isJdbcPrimitive
          then  "${p.fieldType} ${p.fieldName} = (${p.fieldType}) rs.getObject(${p.colIdx});"
          else  "${p.fieldType} ${p.fieldName} = rs.${p.jdbcGetter}(${p.colIdx});"
      )
