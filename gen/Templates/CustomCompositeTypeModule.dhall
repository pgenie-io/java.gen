let Algebra = ../Algebras/Template.dhall

let Deps = ../Deps/package.dhall

let Field =
      { pgName : Text
      , fieldName : Text
      , fieldType : Text
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

                    in  "Codec.<${params.typeName}, ${field.rawCodecType}>field(\"${field.pgName}\", ${codecExpr}, ${getterExpr})"
                )
                params.fields

        let indexedFields = Deps.Prelude.List.indexed Field params.fields

        let constructorArgs =
              Deps.Prelude.Text.concatMapSep
                ", "
                { index : Natural, value : Field }
                ( \(field : { index : Natural, value : Field }) ->
                    "(( ${field.value.fieldType} ) objects[${Natural/show
                                                               field.index}])"
                )
                indexedFields

        let constructorExpr =
              "objects -> new ${params.typeName}(${constructorArgs})"

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
              # ( if    hasOptionalFields || hasElementOptionalFields
                  then  [ "import java.util.Optional;" ]
                  else  [] : List Text
                )

        let codecImports = [ "import io.codemine.java.postgresql.jdbc.Codec;" ]

        let importSection =
                  Deps.Prelude.Text.concatSep "\n" javaImports
              ++  "\n\n"
              ++  Deps.Prelude.Text.concatSep "\n" codecImports

        in  ''
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
                    ${Deps.Lude.Extensions.Text.indentNonEmpty 8 fieldDecls}) {

                public static final Codec<${params.typeName}> CODEC = Codec.<${params.typeName}>composite(
                        "${params.pgSchema}", "${params.pgTypeName}",
                        ${constructorExpr},
                        ${Deps.Lude.Extensions.Text.indentNonEmpty
                            12
                            codecFieldEntries});

            }
            ''

in  { Params, Field, run }
