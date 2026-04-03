let Algebra = ./Algebra/package.dhall

let Deps = ../Deps/package.dhall

let Variant = { name : Text, pgValue : Text }

let Params =
      { typeName : Text
      , pgSchema : Text
      , pgTypeName : Text
      , variants : List Variant
      }

let run =
      \(params : Params) ->
        let variantEntries =
              Deps.Prelude.Text.concatMapSep
                ''
                ,
                ''
                Variant
                ( \(variant : Variant) ->
                    ''
                    /**
                     * Corresponds to the PostgreSQL enum variant {@code ${variant.pgValue}}.
                     */
                    ${variant.name}''
                )
                params.variants

        let codecEntries =
              Deps.Prelude.Text.concatMapSep
                ''
                ,
                ''
                Variant
                ( \(variant : Variant) ->
                    "Map.entry(${variant.name}, \"${variant.pgValue}\")"
                )
                params.variants

        in      ''
                import java.util.Map;

                import io.codemine.java.postgresql.codecs.EnumCodec;

                /**
                 * Representation of the {@code ${params.pgTypeName}} user-declared PostgreSQL
                 * enumeration type.
                 *
                 * <p>
                 * Generated from SQL queries using the
                 * <a href="https://pgenie.io">pGenie</a> code generator.
                 */
                public enum ${params.typeName} {

                ''
            ++  "    "
            ++  Deps.Lude.Extensions.Text.indent 4 variantEntries
            ++  ''
                ;

                    public static final EnumCodec<${params.typeName}> CODEC = new EnumCodec<>(
                            "${params.pgSchema}", "${params.pgTypeName}",
                            Map.ofEntries(
                ''
            ++  "                    "
            ++  Deps.Lude.Extensions.Text.indent 20 codecEntries
            ++  ''
                ));

                }''

in  { Params, Variant, run }
