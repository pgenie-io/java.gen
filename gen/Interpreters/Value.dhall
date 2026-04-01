let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Scalar = ./Scalar.dhall

let Input = Model.Value

let Output =
      { javaType : Text
      , boxedJavaType : Text
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

let Result = Sdk.Compiled.Type Output

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Sdk.Compiled.flatMap
          Scalar.Output
          Output
          ( \(scalar : Scalar.Output) ->
              Deps.Prelude.Optional.fold
                Model.ArraySettings
                input.arraySettings
                Result
                ( \(arraySettings : Model.ArraySettings) ->
                    let elementType =
                          if    arraySettings.elementIsNullable
                          then  scalar.boxedJavaType
                          else  scalar.boxedJavaType

                    let arrayType =
                          Natural/fold
                            arraySettings.dimensionality
                            Text
                            (\(inner : Text) -> "List<${inner}>")
                            elementType

                    let inDimSuffix =
                          Natural/fold
                            arraySettings.dimensionality
                            Text
                            (\(inner : Text) -> "${inner}.inDim()")
                            scalar.codecRef

                    in  Sdk.Compiled.ok
                          Output
                          { javaType = arrayType
                          , boxedJavaType = arrayType
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
                ( Sdk.Compiled.ok
                    Output
                    { javaType = scalar.javaType
                    , boxedJavaType = scalar.boxedJavaType
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
          )
          (Scalar.run config input.scalar)

in  Algebra.module Input Output run
