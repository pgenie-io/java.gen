-- Renders the decodeResultSet method for a statement with an optional result.
-- Produces the method without any surrounding indentation; splice site must indent.
let Sdk = ../Deps/Sdk.dhall

let Deps = ../Deps/package.dhall

let indent = Deps.Lude.Text.indentNonEmpty

let Params = { decodeLines : Text, columnNames : List Text, useOptional : Bool }

in  Sdk.Sigs.Template.module
      Params
      ( \(p : Params) ->
          if    p.useOptional
          then  ''
                @Override
                public Optional<ResultRow> decodeResultSet(ResultSet rs) throws SQLException {
                    if (!rs.next()) {
                        return Optional.empty();
                    }
                    ${indent 4 p.decodeLines}

                    return Optional.of(new ResultRow(${Deps.Prelude.Text.concatMapSep
                                                         ", "
                                                         Text
                                                         ( \(col : Text) ->
                                                             "${col}Col"
                                                         )
                                                         p.columnNames}));
                }''
          else  ''
                @Override
                public Result decodeResultSet(ResultSet rs) throws SQLException {
                    if (!rs.next()) {
                        return null;
                    }
                    ${indent 4 p.decodeLines}

                    return new Result(${Deps.Prelude.Text.concatMapSep
                                          ", "
                                          Text
                                          (\(col : Text) -> "${col}Col")
                                          p.columnNames});
                }''
      )
