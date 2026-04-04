-- Renders the per-row decode body, optionally wrapped in a DecodingException try-catch.
-- Produces the body content without any surrounding indentation; splice site must indent.
let Algebra = ../Algebra/package.dhall

let Deps = ../../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params =
      { hasCodecDecode : Bool, decodeLines : Text, finalStatement : Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          if    p.hasCodecDecode
          then  ''
                try {
                    ${indent 4 p.decodeLines}

                    ${p.finalStatement}
                } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                    throw new IllegalStateException(e);
                }''
          else  ''
                ${p.decodeLines}
                ${p.finalStatement}''
      )
