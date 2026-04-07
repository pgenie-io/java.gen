-- Renders a single PreparedStatement binding statement for one parameter occurrence.
-- idx: 1-based string index (e.g. "1", "2").
-- Produces the statement(s) without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Params =
      { idx : Text
      , fieldName : Text
      , codecRef : Text
      , isOptional : Bool
      , elementIsOptional : Bool
      }

let valueExpr =
      \(p : Params) ->
        if    p.isOptional
        then  if    p.elementIsOptional
              then  "this.${p.fieldName}().map(list -> list.stream().map(o -> o.orElse(null)).toList()).orElse(null)"
              else  "this.${p.fieldName}().orElse(null)"
        else  if p.elementIsOptional
        then  "this.${p.fieldName}() == null ? null : this.${p.fieldName}().stream().map(o -> o.orElse(null)).toList()"
        else  "this.${p.fieldName}()"

in  Algebra.module
      Params
      (\(p : Params) -> "${p.codecRef}.bind(ps, ${p.idx}, ${valueExpr p});")
