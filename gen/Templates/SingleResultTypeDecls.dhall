-- Renders the row type declaration for a single-row or optional result.
-- `rowTypeName` is "Result" for single-cardinality and "ResultRow" for optional-cardinality.
-- Produces the declaration without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Deps = ../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { typeNameBase : Text, columnFieldList : Text, rowTypeName : Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
          /**
           * Result of the statement parameterised by {@link ${p.typeNameBase}}.
           */
          public record ${p.rowTypeName}(
                  ${indent 8 p.columnFieldList}) {}''
      )
