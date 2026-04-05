let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Value = ./Value.dhall

let StatementModuleSub = ../Templates/StatementModule/package.dhall

let Input = Model.Member

let Output =
      { columnField : Text
      , fieldName : Text
      , fieldType : Text
      , boxedJavaType : Text
      , elementIsOptional : Bool
      , useCodec : Bool
      , isDateType : Bool
      , isJdbcPrimitive : Bool
      , jdbcGetter : Text
      , codecRef : Text
      , isNullable : Bool
      , isOptional : Bool
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
                    then  "Optional<${value.boxedJavaType}>"
                    else  if input.isNullable
                    then  value.boxedJavaType
                    else  value.javaType

              in  Sdk.Compiled.ok
                    Output
                    { columnField =
                        StatementModuleSub.ResultColumnField.run
                          { pgName = input.pgName
                          , fieldType
                          , fieldName
                          , isNullable = input.isNullable
                          }
                    , fieldName
                    , fieldType
                    , boxedJavaType = value.boxedJavaType
                    , elementIsOptional = value.elementIsOptional
                    , useCodec = value.useCodec
                    , isDateType = value.isDateType
                    , isJdbcPrimitive = value.isJdbcPrimitive
                    , jdbcGetter = value.jdbcGetter
                    , codecRef = value.codecRef
                    , isNullable = input.isNullable
                    , isOptional
                    }
          )
          ( Sdk.Compiled.nest
              Value.Output
              input.pgName
              (Value.run config input.value)
          )

in  Algebra.module Input Output run
