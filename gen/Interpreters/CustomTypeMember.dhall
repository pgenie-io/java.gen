let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Lude = Deps.Lude

let Model = Deps.Sdk.Project

let Value = ./Value.dhall

let Name = ./Name.dhall

let Input = Model.Member

let Output =
      { fieldName : Text
      , fieldType : Text
      , boxedJavaType : Text
      , rawCodecType : Text
      , elementIsOptional : Bool
      , pgName : Text
      , codecRef : Text
      , imports : ImportSet.Type
      , isOptional : Bool
      , isNullable : Bool
      , testPresentLiteral : Text
      , testAbsentLiteral : Text
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let combine =
              \(name : Name.Output) ->
              \(value : Value.Output) ->
                let fieldName = name.fieldName

                let isOptional = config.useOptional && input.isNullable

                let fieldType =
                      if    isOptional
                      then  "Optional<${value.boxedJavaType}>"
                      else  if input.isNullable
                      then  value.boxedJavaType
                      else  value.javaType

                let testPresentLiteral =
                      if    isOptional
                      then  "Optional.of(${value.testDefaultLiteral})"
                      else  value.testDefaultLiteral

                let testAbsentLiteral =
                      if isOptional then "Optional.empty()" else "null"

                in  { fieldName
                    , fieldType
                    , boxedJavaType = value.boxedJavaType
                    , rawCodecType = value.rawCodecType
                    , elementIsOptional = value.elementIsOptional
                    , pgName = input.pgName
                    , codecRef = value.codecRef
                    , imports = value.imports
                    , isOptional
                    , isNullable = input.isNullable
                    , testPresentLiteral
                    , testAbsentLiteral
                    }

        in  Lude.Compiled.map2
              Name.Output
              Value.Output
              Output
              combine
              ( Lude.Compiled.nest
                  Name.Output
                  input.pgName
                  (Name.run config input.name)
              )
              ( Lude.Compiled.nest
                  Value.Output
                  input.pgName
                  (Value.run config input.value)
              )

in  Algebra.module Input Output run
