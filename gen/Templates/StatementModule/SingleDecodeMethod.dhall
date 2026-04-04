-- Renders the decodeResultSet method for a statement that always returns exactly one row.
-- Produces the method without any surrounding indentation; splice site must indent.
let Algebra = ../Algebra/package.dhall

let Deps = ../../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { decodeBody : Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
          @Override
          public Output decodeResultSet(ResultSet rs) throws SQLException {
              rs.next();
              ${indent 4 p.decodeBody}
          }''
      )
