-- Renders a single PreparedStatement binding statement for one parameter occurrence.
-- idx: 1-based string index (e.g. "1", "2").
-- Produces the statement(s) without any surrounding indentation; splice site must indent.
let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Params =
      { idx : Text
      , fieldName : Text
      , codecRef : Text
      , isOptional : Bool
      , elementIsOptional : Bool
      , dims : Natural
      }

let unwrapSuffix =
      \(dims : Natural) ->
        Natural/fold
          (Prelude.Natural.subtract 1 dims)
          Text
          (\(inner : Text) -> ".stream().map(d -> d${inner}).toList()")
          ".stream().map(o -> o.orElse(null)).toList()"

let valueExpr =
      \(p : Params) ->
        if    p.isOptional
        then  if    p.elementIsOptional
              then  "this.${p.fieldName}().map(outer -> outer${unwrapSuffix
                                                                 p.dims}).orElse(null)"
              else  "this.${p.fieldName}().orElse(null)"
        else  if p.elementIsOptional
        then  "this.${p.fieldName}() == null ? null : this.${p.fieldName}()${unwrapSuffix
                                                                               p.dims}"
        else  "this.${p.fieldName}()"

in  Sdk.Sigs.template
      Params
      (\(p : Params) -> "${p.codecRef}.bind(ps, ${p.idx}, ${valueExpr p});")
