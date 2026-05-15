let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Value = ./Value.dhall

let Input = Model.Member

let Output =
      { fieldName : Text
      , fieldType : Text
      , boxedJavaType : Text
      , rawCodecType : Text
      , elementIsOptional : Bool
      , pgName : Text
      , isDateType : Bool
      , codecRef : Text
      , imports : Deps.ImportSet.Struct
      , isOptional : Bool
      , isNullable : Bool
      , testPresentLiteral : Text
      , testAbsentLiteral : Text
      , testLiteralIsNull : Bool
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Sdk.Compiled.map
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

              let testPresentLiteral =
                    if    isOptional
                    then  if    value.testLiteralIsNull
                          then  "Optional.empty()"
                          else  "Optional.of(${value.testDefaultLiteral})"
                    else  value.testDefaultLiteral

              let testAbsentLiteral =
                    if isOptional then "Optional.empty()" else "null"

              in  { fieldName
                  , fieldType
                  , boxedJavaType = value.boxedJavaType
                  , rawCodecType = value.rawCodecType
                  , elementIsOptional = value.elementIsOptional
                  , pgName = input.pgName
                  , isDateType = value.isDateType
                  , codecRef = value.codecRef
                  , imports = value.imports
                  , isOptional
                  , isNullable = input.isNullable
                  , testPresentLiteral
                  , testAbsentLiteral
                  , testLiteralIsNull = value.testLiteralIsNull
                  }
          )
          ( Sdk.Compiled.nest
              Value.Output
              input.pgName
              (Value.run config input.value)
          )

in  Algebra.module Input Output run
