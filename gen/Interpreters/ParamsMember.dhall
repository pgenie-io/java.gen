let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Value = ./Value.dhall

let Input = Model.Member

let Output =
      { fieldName : Text
      , fieldType : Text
      , pgName : Text
      , pgCastSuffix : Text
      , isDateType : Bool
      , jdbcSetter : Text
      , sqlTypesConstant : Text
      , codecRef : Text
      , imports : List Text
      , isNullable : Bool
      , isOptional : Bool
      , elementIsOptional : Bool
      , needsCustomTypeImport : Bool
      , testDefaultLiteral : Text
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

              in  { fieldName
                  , fieldType
                  , pgName = input.pgName
                  , pgCastSuffix = value.pgCastSuffix
                  , isDateType = value.isDateType
                  , jdbcSetter = value.jdbcSetter
                  , sqlTypesConstant = value.sqlTypesConstant
                  , codecRef = value.codecRef
                  , imports = value.imports
                  , isNullable = input.isNullable
                  , isOptional
                  , elementIsOptional = value.elementIsOptional
                  , needsCustomTypeImport = value.needsCustomTypeImport
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
