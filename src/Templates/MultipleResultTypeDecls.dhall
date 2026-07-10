-- Renders the Result and ResultRow type declarations for a multiple-row result.
-- Produces the declarations without any surrounding indentation; splice site must indent.
let Sdk = ../Deps/Sdk.dhall

let Lude = ../Deps/Lude.dhall

let indent = Lude.Text.indentNonEmpty

let Params = { typeNameBase : Text, columnFieldList : Text }

in  Sdk.Sigs.template
      Params
      ( \(p : Params) ->
          ''
          /**
           * Result of the statement parameterised by {@link ${p.typeNameBase}}.
           */
          public static final class Result extends ArrayList<ResultRow> {
              Result() {}
          }

          /**
           * Row of {@link Result}.
           */
          public record ResultRow(
                  ${indent 8 p.columnFieldList}) {}''
      )
