let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Value = ./Value.dhall

let Input = Model.Member

let Output =
      { fieldName : Text
      , fieldType : Text
      , boxedJavaType : Text
      , pgName : Text
      , pgCastSuffix : Text
      , useCodec : Bool
      , isDateType : Bool
      , isJdbcPrimitive : Bool
      , jdbcSetter : Text
      , jdbcGetter : Text
      , sqlTypesConstant : Text
      , codecRef : Text
      , isNullable : Bool
      , isOptional : Bool
      , testDefaultLiteral : Text
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Sdk.Compiled.flatMap
          Value.Output
          Output
          ( \(value : Value.Output) ->
              let fieldName = Deps.CodegenKit.Name.toTextInCamel input.name

              let isOptional = config.useOptional && input.isNullable

              let fieldType =
                    if    isOptional
                    then  "Optional<" ++ value.boxedJavaType ++ ">"
                    else  if input.isNullable
                    then  value.boxedJavaType
                    else  value.javaType

              in  Sdk.Compiled.ok
                    Output
                    { fieldName
                    , fieldType
                    , boxedJavaType = value.boxedJavaType
                    , pgName = input.pgName
                    , pgCastSuffix = value.pgCastSuffix
                    , useCodec = value.useCodec
                    , isDateType = value.isDateType
                    , isJdbcPrimitive = value.isJdbcPrimitive
                    , jdbcSetter = value.jdbcSetter
                    , jdbcGetter = value.jdbcGetter
                    , sqlTypesConstant = value.sqlTypesConstant
                    , codecRef = value.codecRef
                    , isNullable = input.isNullable
                    , isOptional
                    , testDefaultLiteral =
                        if    isOptional
                        then  "Optional.empty()"
                        else  if input.isNullable
                        then  "null"
                        else  value.testDefaultLiteral
                    }
          )
          ( Sdk.Compiled.nest
              Value.Output
              input.pgName
              (Value.run config input.value)
          )

in  Algebra.module Input Output run
