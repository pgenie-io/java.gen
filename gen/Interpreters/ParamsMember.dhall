let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Lude = Deps.Lude

let Model = Deps.Sdk.Project

let Value = ./Value.dhall

let JavaIdentifier = ../Utilities/JavaIdentifier.dhall

let Input = Model.Member

let Output =
      { fieldName : Text
      , fieldType : Text
      , pgName : Text
      , pgCastSuffix : Text
      , codecRef : Text
      , imports : ImportSet.Type
      , isNullable : Bool
      , isOptional : Bool
      , elementIsOptional : Bool
      , dims : Natural
      , needsCustomTypeImport : Bool
      , testDefaultLiteral : Text
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Lude.Compiled.map
          Value.Output
          Output
          ( \(value : Value.Output) ->
              let fieldName = JavaIdentifier.escape input.name.inCamelCase

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
                  , codecRef = value.codecRef
                  , imports = value.imports
                  , isNullable = input.isNullable
                  , isOptional
                  , elementIsOptional = value.elementIsOptional
                  , dims =
                      Deps.Prelude.Optional.fold
                        Deps.Sdk.Project.ArraySettings
                        input.value.arraySettings
                        Natural
                        ( \(arr : Deps.Sdk.Project.ArraySettings) ->
                            arr.dimensionality
                        )
                        0
                  , needsCustomTypeImport = value.needsCustomTypeImport
                  , testDefaultLiteral =
                      if    isOptional
                      then  "Optional.empty()"
                      else  value.testDefaultLiteral
                  }
          )
          ( Lude.Compiled.nest
              Value.Output
              input.pgName
              (Value.run config input.value)
          )

in  Algebra.module Input Output run
