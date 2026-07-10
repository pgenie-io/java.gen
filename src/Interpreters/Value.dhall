let ImportSet = ../Structures/ImportSet.dhall

let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Model = ../Deps/Contract.dhall

let Scalar = ./Scalar.dhall

let Config = { useOptional : Bool }

let Input = Model.Value

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , rawCodecType : Text
      , elementIsOptional : Bool
      , codecRef : Text
      , imports : ImportSet.Type
      , pgCastSuffix : Text
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
      }

let run =
      \(config : Config) ->
      \(input : Input) ->
        Lude.Compiled.map
          Scalar.Output
          Output
          ( \(scalar : Scalar.Output) ->
              Prelude.Optional.fold
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
                        , pgCastSuffix =
                            merge
                              { None = ""
                              , Some =
                                  \(suffix : Text) ->
                                        suffix
                                    ++  Prelude.Text.replicate
                                          arraySettings.dimensionality
                                          "[]"
                              }
                              scalar.pgCastSuffix
                        , testDefaultLiteral = "List.of()"
                        , testRandomLiteral = "List.of()"
                        }
                )
                { javaType = scalar.javaType
                , boxedJavaType = scalar.boxedJavaType
                , rawCodecType = scalar.boxedJavaType
                , elementIsOptional = False
                , codecRef = scalar.codecRef
                , imports = scalar.imports
                , pgCastSuffix =
                    merge
                      { None = "", Some = \(suffix : Text) -> suffix }
                      scalar.pgCastSuffix
                , testDefaultLiteral = scalar.testDefaultLiteral
                , testRandomLiteral = scalar.testRandomLiteral
                }
          )
          (Scalar.run {=} input.scalar)

in  Sdk.Sigs.Interpreter.module Config Input Output run
