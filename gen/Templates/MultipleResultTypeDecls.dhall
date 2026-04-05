-- Renders the Output and OutputRow type declarations for a multiple-row result.
-- Produces the declarations without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Deps = ../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { typeNameBase : Text, columnFieldList : Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
          /**
           * Result of the statement parameterised by {@link ${p.typeNameBase}}.
           */
          public static final class Output extends ArrayList<OutputRow> {
              Output() {}
          }

          /**
           * Row of {@link Output}.
           */
          public record OutputRow(
                  ${indent 8 p.columnFieldList}) {}''
      )
