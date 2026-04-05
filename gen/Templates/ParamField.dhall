-- Renders a single parameter field entry for the record declaration.
-- Produces the field without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Params =
      { pgName : Text, fieldType : Text, fieldName : Text, isNullable : Bool }

in  Algebra.module
      Params
      ( \(params : Params) ->
          let nullableDoc = if params.isNullable then " Nullable." else ""

          in  ''
              /**
               * Maps to {@code $${params.pgName}} in the template.${nullableDoc}
               */
              ${params.fieldType} ${params.fieldName}''
      )
