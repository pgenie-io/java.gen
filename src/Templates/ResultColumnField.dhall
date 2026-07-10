-- Renders a single result-set column field entry for the ResultRow record.
-- Produces the field without any surrounding indentation; splice site must indent.
let Sdk = ../Deps/Sdk.dhall

let Params =
      { pgName : Text, fieldType : Text, fieldName : Text, isNullable : Bool }

in  Sdk.Sigs.Template.module
      Params
      ( \(params : Params) ->
          let nullableDoc = if params.isNullable then " Nullable." else ""

          in  ''
              /**
               * Maps to the {@code ${params.pgName}} result-set column.${nullableDoc}
               */
              ${params.fieldType} ${params.fieldName}''
      )
