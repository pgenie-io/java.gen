let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Scalar = ./Scalar.dhall

let Input = Model.Value

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , rawCodecType : Text
      , elementIsOptional : Bool
      , codecRef : Text
      , useCodec : Bool
      , isDateType : Bool
      , isJdbcPrimitive : Bool
      , jdbcSetter : Text
      , jdbcGetter : Text
      , sqlTypesConstant : Text
      , pgCastSuffix : Text
      , testDefaultLiteral : Text
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Sdk.Compiled.map
          Scalar.Output
          Output
          ( \(scalar : Scalar.Output) ->
              Deps.Prelude.Optional.fold
                Model.ArraySettings
                input.arraySettings
                Output
                ( \(arraySettings : Model.ArraySettings) ->
                    let elementIsOptional =
                          config.useOptional && arraySettings.elementIsNullable

                    let elementType =
                          if    elementIsOptional
                          then  "Optional<${scalar.boxedJavaType}>"
                          else  scalar.boxedJavaType

                    let arrayType =
                          Natural/fold
                            arraySettings.dimensionality
                            Text
                            (\(inner : Text) -> "List<${inner}>")
                            elementType

                    let rawArrayType =
                          Natural/fold
                            arraySettings.dimensionality
                            Text
                            (\(inner : Text) -> "List<${inner}>")
                            scalar.boxedJavaType

                    let inDimSuffix =
                          Natural/fold
                            arraySettings.dimensionality
                            Text
                            (\(inner : Text) -> "${inner}.inDim()")
                            scalar.codecRef

                    in  { javaType = arrayType
                        , boxedJavaType = arrayType
                        , rawCodecType = rawArrayType
                        , elementIsOptional
                        , codecRef = inDimSuffix
                        , useCodec = True
                        , isDateType = False
                        , isJdbcPrimitive = False
                        , jdbcSetter = ""
                        , jdbcGetter = ""
                        , sqlTypesConstant = ""
                        , pgCastSuffix = scalar.pgCastSuffix
                        , testDefaultLiteral = "null"
                        }
                )
                { javaType = scalar.javaType
                , boxedJavaType = scalar.boxedJavaType
                , rawCodecType = scalar.boxedJavaType
                , elementIsOptional = False
                , codecRef = scalar.codecRef
                , useCodec = scalar.useCodec
                , isDateType = scalar.isDateType
                , isJdbcPrimitive = scalar.isJdbcPrimitive
                , jdbcSetter = scalar.jdbcSetter
                , jdbcGetter = scalar.jdbcGetter
                , sqlTypesConstant = scalar.sqlTypesConstant
                , pgCastSuffix = scalar.pgCastSuffix
                , testDefaultLiteral = scalar.testDefaultLiteral
                }
          )
          (Scalar.run config input.scalar)

in  Algebra.module Input Output run
