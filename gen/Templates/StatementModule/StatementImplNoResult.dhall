-- Renders the Statement interface method implementations for a no-result statement.
-- Produces the methods without any surrounding indentation; splice site must indent.
let Algebra = ../Algebra/package.dhall

let Deps = ../../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { sqlExp : Text, paramBindCode : Text }

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

          /**
           * Returns the number of rows affected by the statement.
           */
          @Override
          public boolean returnsRows() {
              return false;
          }

          /**
           * Returns the number of rows affected by the statement.
           *
           * <p>
           * Uses {@code affectedRows} forwarded from
           * {@link java.sql.PreparedStatement#executeUpdate()}.
           */
          @Override
          public Long decodeAffectedRows(long affectedRows) throws SQLException {
              return affectedRows;
          }

          @Override
          public Long decodeResultSet(ResultSet rs) {
              throw new UnsupportedOperationException();
          }''
      )
