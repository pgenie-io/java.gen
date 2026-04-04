-- Renders the decodeResultSet method for a statement with an optional result (may return null).
-- Produces the method without any surrounding indentation; splice site must indent.
let Algebra = ../Algebra/package.dhall

let Deps = ../../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { decodeLines : Text, columnNames : List Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
          @Override
          public Output decodeResultSet(ResultSet rs) throws SQLException {
              if (!rs.next()) {
                  return null;
              }
              ${indent 4 p.decodeLines}

              return new Output(${Deps.Prelude.Text.concatMapSep
                                    ", "
                                    Text
                                    (\(col : Text) -> "${col}Col")
                                    p.columnNames});
          }''
      )
