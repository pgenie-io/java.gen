let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let indent = Lude.Text.indentNonEmpty

let Params = { decodeLines : Text, columnNames : List Text }

in  Sdk.Sigs.template
      Params
      ( \(p : Params) ->
          ''
          @Override
          public Result decodeResultSet(ResultSet rs) throws SQLException {
              rs.next();

              ${indent 4 p.decodeLines}

              return new Result(${Prelude.Text.concatMapSep
                                    ", "
                                    Text
                                    (\(col : Text) -> "${col}Col")
                                    p.columnNames});
          }''
      )
