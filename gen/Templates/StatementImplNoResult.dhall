-- Renders the Statement interface method implementations for a no-result statement.
-- Produces the methods without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Deps = ../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = {}

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
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
