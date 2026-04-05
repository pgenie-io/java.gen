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
              rs.next();

              ${indent 4 p.decodeLines}

              return new Result(${Deps.Prelude.Text.concatMapSep
                                    ", "
                                    Text
                                    (\(col : Text) -> "${col}Col")
                                    p.columnNames});
          }''
      )
