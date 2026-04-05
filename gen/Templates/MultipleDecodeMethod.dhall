-- Renders the decodeResultSet method for a statement with multiple-row results.
-- Produces the method without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Deps = ../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { decodeLines : Text, columnNames : List Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
          @Override
          public Result decodeResultSet(ResultSet rs) throws SQLException {
              Result output = new Result();
              int row = 0;
              
              while (rs.next()) {
                  ${indent 8 p.decodeLines}

                  output.add(new ResultRow(${Deps.Prelude.Text.concatMapSep
                                               ", "
                                               Text
                                               (\(col : Text) -> "${col}Col")
                                               p.columnNames}));
                  row++;
              }

              return output;
          }''
      )
