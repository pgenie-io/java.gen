let Deps = ../Deps/package.dhall

let Field =
      { pgName : Text
      , fieldName : Text
      , fieldType : Text
      , rawCodecType : Text
      , elementIsOptional : Bool
      , codecRef : Text
      , isDateType : Bool
      , isOptional : Bool
      }

let Params =
      { packageName : Text
      , typeName : Text
      , pgSchema : Text
      , pgTypeName : Text
      , extraImports : Deps.ImportSet.Struct
      , fields : List Field
      }

let importIf =
      \(condition : Bool) ->
      \(import : Text) ->
        if condition then [ import ] else [] : List Text

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
                    let getterExpr =
                          if    field.isOptional
                          then  if    field.elementIsOptional
                                then  "row -> row.${field.fieldName}().map(list -> list.stream().map(o -> o.orElse(null)).toList()).orElse(null)"
                                else  "row -> row.${field.fieldName}().orElse(null)"
                          else  if field.elementIsOptional
                          then  "row -> row.${field.fieldName}().stream().map(o -> o.orElse(null)).toList()"
                          else  "${params.typeName}::${field.fieldName}"

                    in  "Codec.<${params.typeName}, ${field.rawCodecType}>field(\"${field.pgName}\", ${field.codecRef}, ${getterExpr})"
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

        let imports =
                [ "java.time.*", "java.util.List" ]
              # ( if    hasOptionalFields || hasElementOptionalFields
                  then  [ "java.util.Optional" ]
                  else  [] : List Text
                )
              # importIf
                  params.extraImports.codecs
                  "io.codemine.java.postgresql.codecs.*"
              # importIf
                  params.extraImports.jsonNode
                  "com.fasterxml.jackson.databind.JsonNode"
              # importIf params.extraImports.bigDecimal "java.math.BigDecimal"
              # importIf params.extraImports.uuid "java.util.UUID"
              # [ "io.codemine.java.postgresql.jdbc.Codec" ]

        let importSection =
              Deps.Prelude.Text.concatMapSep
                "\n"
                Text
                (\(import : Text) -> "import ${import};")
                imports

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
