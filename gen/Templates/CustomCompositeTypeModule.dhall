let Algebra = ./Algebra/package.dhall

let Deps = ../Deps/package.dhall

let Field =
      { pgName : Text
      , fieldName : Text
      , fieldType : Text
      , boxedJavaType : Text
      , rawCodecType : Text
      , elementIsOptional : Bool
      , codecRef : Text
      , useCodec : Bool
      , isDateType : Bool
      , isOptional : Bool
      }

let Params =
      { packageName : Text
      , typeName : Text
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
                     * Maps to {@code ${field.pgName}}.
                     */
                    ${field.fieldType} ${field.fieldName}''
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

                    let getterExpr =
                          if    field.isOptional
                          then  if    field.elementIsOptional
                                then  "row -> row.${field.fieldName}().map(list -> list.stream().map(o -> o.orElse(null)).toList()).orElse(null)"
                                else  "row -> row.${field.fieldName}().orElse(null)"
                          else  if field.elementIsOptional
                          then  "row -> row.${field.fieldName}().stream().map(o -> o.orElse(null)).toList()"
                          else  "${params.typeName}::${field.fieldName}"

                    in  "new CompositeCodec.Field<>(\"${field.pgName}\", ${getterExpr}, ${codecExpr})"
                )
                params.fields

        let curriedConstructor =
              let paramDecls =
                    Deps.Prelude.Text.concatMap
                      Field
                      ( \(field : Field) ->
                          let paramType =
                                if    field.elementIsOptional
                                then  field.rawCodecType
                                else  if field.isOptional
                                then  field.boxedJavaType
                                else  field.fieldType

                          in  "(${paramType} ${field.fieldName}) -> "
                      )
                      params.fields

              let constructorArgs =
                    Deps.Prelude.Text.concatMapSep
                      ", "
                      Field
                      ( \(field : Field) ->
                          if    field.isOptional
                          then  if    field.elementIsOptional
                                then  "Optional.ofNullable(${field.fieldName}).map(list -> list.stream().map(Optional::ofNullable).toList())"
                                else  "Optional.ofNullable(${field.fieldName})"
                          else  if field.elementIsOptional
                          then  "${field.fieldName}.stream().map(Optional::ofNullable).toList()"
                          else  field.fieldName
                      )
                      params.fields

              in  ''
                  ${paramDecls}new ${params.typeName}(
                                      ${constructorArgs})''

        let hasOptionalFields =
              Deps.Prelude.List.any
                Field
                (\(field : Field) -> field.isOptional)
                params.fields

        let hasElementOptionalFields =
              Deps.Prelude.List.any
                Field
                (\(field : Field) -> field.elementIsOptional)
                params.fields

        let javaImports =
                [ "import java.time.*;", "import java.util.List;" ]
              # ( if    hasOptionalFields
                  then  [ "import java.util.Optional;" ]
                  else  [] : List Text
                )

        let codecImports =
              [ "import io.codemine.java.postgresql.codecs.Codec;"
              , "import io.codemine.java.postgresql.codecs.CompositeCodec;"
              ]

        let importSection =
                  Deps.Prelude.Text.concatSep "\n" javaImports
              ++  "\n\n"
              ++  Deps.Prelude.Text.concatSep "\n" codecImports

        in      ''
                package ${params.packageName}.types;

                ${importSection}

                /**
                 * Representation of the {@code ${params.pgTypeName}} user-declared PostgreSQL
                 * composite (record) type.
                 *
                 * <p>
                 * Generated from SQL queries using the
                 * <a href="https://pgenie.io">pGenie</a> code generator.
                 *
                 * <p>
                 * All fields are nullable, matching the PostgreSQL column definitions.
                 */
                public record ${params.typeName}(
                ''
            ++  "        "
            ++  Deps.Lude.Extensions.Text.indentNonEmpty 8 fieldDecls
            ++  ''
                ) {

                    public static final CompositeCodec<${params.typeName}> CODEC = new CompositeCodec<>(
                            "${params.pgSchema}", "${params.pgTypeName}",
                            ''
            ++  curriedConstructor
            ++  ''
                ,
                ''
            ++  "            "
            ++  Deps.Lude.Extensions.Text.indentNonEmpty 12 codecFieldEntries
            ++  ''
                );

                }
                ''

in  { Params, Field, run }
