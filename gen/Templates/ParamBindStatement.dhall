-- Renders a single PreparedStatement binding statement for one parameter occurrence.
-- idx: 1-based string index (e.g. "1", "2").
-- Produces the statement(s) without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Params =
      { idx : Text
      , fieldName : Text
      , useCodec : Bool
      , codecRef : Text
      , isDateType : Bool
      , isOptional : Bool
      , isNullable : Bool
      , jdbcSetter : Text
      , sqlTypesConstant : Text
      }

in  Algebra.module
      Params
      ( \(p : Params) ->
          if    p.useCodec
          then  if    p.isOptional
                then  "new JdbcCodec<>(${p.codecRef}).bind(ps, ${p.idx}, this.${p.fieldName}().orElse(null));"
                else  "new JdbcCodec<>(${p.codecRef}).bind(ps, ${p.idx}, this.${p.fieldName}());"
          else  if p.isDateType
          then  if    p.isOptional
                then  ''
                      if (this.${p.fieldName}().isPresent()) {
                          ps.setDate(${p.idx}, Date.valueOf(this.${p.fieldName}().get()));
                      } else {
                          ps.setNull(${p.idx}, Types.DATE);
                      }''
                else  if p.isNullable
                then  ''
                      if (this.${p.fieldName}() != null) {
                          ps.setDate(${p.idx}, Date.valueOf(this.${p.fieldName}()));
                      } else {
                          ps.setNull(${p.idx}, Types.DATE);
                      }''
                else  "ps.setDate(${p.idx}, Date.valueOf(this.${p.fieldName}()));"
          else  if p.isOptional
          then  ''
                if (this.${p.fieldName}().isPresent()) {
                    ps.${p.jdbcSetter}(${p.idx}, this.${p.fieldName}().get());
                } else {
                    ps.setNull(${p.idx}, Types.${p.sqlTypesConstant});
                }''
          else  if p.isNullable
          then  ''
                if (this.${p.fieldName}() != null) {
                    ps.${p.jdbcSetter}(${p.idx}, this.${p.fieldName}());
                } else {
                    ps.setNull(${p.idx}, Types.${p.sqlTypesConstant});
                }''
          else  "ps.${p.jdbcSetter}(${p.idx}, this.${p.fieldName}());"
      )
