let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

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
      , imports : List Text
      , isDateType : Bool
      , jdbcSetter : Text
      , sqlTypesConstant : Text
      , pgCastSuffix : Text
      , needsCustomTypeImport : Bool
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
                            "${scalar.codecRef}"

                    in  { javaType = arrayType
                        , boxedJavaType = arrayType
                        , rawCodecType = rawArrayType
                        , elementIsOptional
                        , codecRef = "${inDimSuffix}"
                        , imports = scalar.imports
                        , isDateType = False
                        , jdbcSetter = ""
                        , sqlTypesConstant = ""
                        , pgCastSuffix =
                            merge
                              { None = ""
                              , Some =
                                  \(suffix : Text) ->
                                        suffix
                                    ++  Deps.Prelude.Text.replicate
                                          arraySettings.dimensionality
                                          "[]"
                              }
                              scalar.pgCastSuffix
                        , needsCustomTypeImport = scalar.needsCustomTypeImport
                        , testDefaultLiteral = "null"
                        }
                )
                { javaType = scalar.javaType
                , boxedJavaType = scalar.boxedJavaType
                , rawCodecType = scalar.boxedJavaType
                , elementIsOptional = False
                , codecRef = scalar.codecRef
                , imports = scalar.imports
                , isDateType = scalar.isDateType
                , jdbcSetter = scalar.jdbcSetter
                , sqlTypesConstant = scalar.sqlTypesConstant
                , pgCastSuffix =
                    merge
                      { None = "", Some = \(suffix : Text) -> suffix }
                      scalar.pgCastSuffix
                , needsCustomTypeImport = scalar.needsCustomTypeImport
                , testDefaultLiteral = scalar.testDefaultLiteral
                }
          )
          (Scalar.run config input.scalar)

in  Algebra.module Input Output run
