let Algebra = ./Algebra/package.dhall

let Deps = ../Deps/package.dhall

let Field =
      { pgName : Text
      , fieldName : Text
      , fieldType : Text
      , codecRef : Text
      , useCodec : Bool
      , isDateType : Bool
      }

let Params =
      { typeName : Text
      , pgSchema : Text
      , pgTypeName : Text
      , fields : List Field
      }

let run =
      \(params : Params) ->
        let fieldDecls =
              Deps.Prelude.Text.concatMapSep
                ''
                ,
                ''
                Field
                ( \(field : Field) ->
                        ''
                                /**
                        ''
                    ++  "         * Maps to {@code "
                    ++  field.pgName
                    ++  ''
                        }.
                        ''
                    ++  ''
                                 */
                        ''
                    ++  "        "
                    ++  field.fieldType
                    ++  " "
                    ++  field.fieldName
                )
                params.fields

        let codecFieldEntries =
              Deps.Prelude.Text.concatMapSep
                ''
                ,
                ''
                Field
                ( \(field : Field) ->
                    let codecExpr =
                          if    field.useCodec
                          then  field.codecRef
                          else  if field.isDateType
                          then  "Codec.DATE"
                          else  field.codecRef

                    in      "            new CompositeCodec.Field<>(\""
                        ++  field.pgName
                        ++  "\", "
                        ++  params.typeName
                        ++  "::"
                        ++  field.fieldName
                        ++  ", "
                        ++  codecExpr
                        ++  ")"
                )
                params.fields

        let curriedConstructor =
              let paramDecls =
                    Deps.Prelude.Text.concatMap
                      Field
                      ( \(field : Field) ->
                              "("
                          ++  field.fieldType
                          ++  " "
                          ++  field.fieldName
                          ++  ") -> "
                      )
                      params.fields

              let constructorArgs =
                    Deps.Prelude.Text.concatMapSep
                      ", "
                      Field
                      (\(field : Field) -> field.fieldName)
                      params.fields

              in      paramDecls
                  ++  "new "
                  ++  params.typeName
                  ++  ''
                      (
                                          ''
                  ++  constructorArgs
                  ++  ")"

        in      ''
                import java.time.*;
                ''
            ++  ''
                import java.util.List;
                ''
            ++  "\n"
            ++  ''
                import io.codemine.java.postgresql.codecs.Codec;
                ''
            ++  ''
                import io.codemine.java.postgresql.codecs.CompositeCodec;
                ''
            ++  "\n"
            ++  ''
                /**
                ''
            ++  " * Representation of the {@code "
            ++  params.pgTypeName
            ++  ''
                } user-declared PostgreSQL
                ''
            ++  ''
                 * composite (record) type.
                ''
            ++  ''
                 *
                ''
            ++  ''
                 * <p>
                ''
            ++  ''
                 * Generated from SQL queries using the
                ''
            ++  ''
                 * <a href="https://pgenie.io">pGenie</a> code generator.
                ''
            ++  ''
                 *
                ''
            ++  ''
                 * <p>
                ''
            ++  ''
                 * All fields are nullable, matching the PostgreSQL column definitions.
                ''
            ++  ''
                 */
                ''
            ++  "public record "
            ++  params.typeName
            ++  ''
                (
                ''
            ++  fieldDecls
            ++  ''
                ) {
                ''
            ++  "\n"
            ++  "    public static final CompositeCodec<"
            ++  params.typeName
            ++  ''
                > CODEC = new CompositeCodec<>(
                ''
            ++  "            \""
            ++  params.pgSchema
            ++  "\", \""
            ++  params.pgTypeName
            ++  ''
                ",
                ''
            ++  "            "
            ++  curriedConstructor
            ++  ''
                ,
                ''
            ++  codecFieldEntries
            ++  ''
                );
                ''
            ++  "\n"
            ++  "}"

in  { Params, Field, run }
