-- Renders a single PreparedStatement binding statement for one parameter occurrence.
-- idx: 1-based string index (e.g. "1", "2").
-- Produces the statement(s) without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Params =
      { idx : Text, fieldName : Text, codecRef : Text, isOptional : Bool }

in  Algebra.module
      Params
      ( \(p : Params) ->
          if    p.isOptional
          then  "${p.codecRef}.bind(ps, ${p.idx}, this.${p.fieldName}().orElse(null));"
          else  "${p.codecRef}.bind(ps, ${p.idx}, this.${p.fieldName}());"
      )
