-- Renders the Statement interface method implementations for a result-returning statement.
-- Produces the methods without any surrounding indentation; splice site must indent.
let Algebra = ../Algebra/package.dhall

let Deps = ../../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params =
      { sqlExp : Text
      , paramBindCode : Text
      , decodeMethod : Text
      , resultTypeName : Text
      }

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
          @Override
          public String sql() {
              return """
                     ${indent 11 p.sqlExp}
                     """;
          }

          @Override
          public void bindParams(PreparedStatement ps) throws SQLException {
              ${indent 4 p.paramBindCode}
          }

          @Override
          public boolean returnsRows() {
              return true;
          }

          ${p.decodeMethod}

          @Override
          public ${p.resultTypeName} decodeAffectedRows(long affectedRows) {
              throw new UnsupportedOperationException();
          }''
      )
