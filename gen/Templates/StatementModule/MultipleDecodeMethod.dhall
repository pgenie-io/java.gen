-- Renders the decodeResultSet method for a statement with multiple-row results.
-- Produces the method without any surrounding indentation; splice site must indent.
let Algebra = ../Algebra/package.dhall

let Deps = ../../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { hasCodecDecode : Bool, decodeLines : Text, varRefs : Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          let rowDecodeLines =
                if    p.hasCodecDecode
                then  ''
                      try {
                          ${indent 4 p.decodeLines}

                          output.add(new OutputRow(${p.varRefs}));
                      } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                          throw new IllegalStateException(e);
                      }''
                else  ''
                      ${p.decodeLines}

                      output.add(new OutputRow(${p.varRefs}));''

          in  ''
              @Override
              public Output decodeResultSet(ResultSet rs) throws SQLException {
                  Output output = new Output();
                  while (rs.next()) {
                      ${indent 8 rowDecodeLines}
                  }

                  return output;
              }''
      )
