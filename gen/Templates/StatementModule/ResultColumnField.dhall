-- Renders a single result-set column field entry for the OutputRow record.
-- Produces the field without any surrounding indentation; splice site must indent.
let Algebra = ../../Algebras/Template.dhall

let Params =
      { pgName : Text, fieldType : Text, fieldName : Text, isNullable : Bool }

in  Algebra.module
      Params
      ( \(params : Params) ->
          let nullableDoc = if params.isNullable then " Nullable." else ""

          in  ''
              /**
               * Maps to the {@code ${params.pgName}} result-set column.${nullableDoc}
               */
              ${params.fieldType} ${params.fieldName}''
      )
