-- Renders the Output type declaration for a single-row or optional result.
-- Produces the declaration without any surrounding indentation; splice site must indent.
let Algebra = ../Algebra/package.dhall

let Deps = ../../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { typeNameBase : Text, columnFieldList : Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
          /**
           * Result of the statement parameterised by {@link ${p.typeNameBase}}.
           */
          public record Output(
                  ${indent 8 p.columnFieldList}) {}''
      )
