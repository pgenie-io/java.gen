let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Value = ./Value.dhall

let Templates = ../Templates/package.dhall

let Input = Model.Member

let Output =
      { columnField : Text
      , fieldName : Text
      , fieldType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , imports : Deps.ImportSet.Struct
      , dims : Natural
      , isNullable : Bool
      , elementIsNullable : Bool
      , needsCustomTypeImport : Bool
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Sdk.Compiled.map
          Value.Output
          Output
          ( \(value : Value.Output) ->
              let fieldName = Deps.CodegenKit.Name.toTextInCamel input.name

              let fieldType =
                    if    input.isNullable
                    then  if    config.useOptional
                          then  "Optional<${value.boxedJavaType}>"
                          else  value.javaType
                    else  value.javaType

              in  { columnField =
                      Templates.ResultColumnField.run
                        { pgName = input.pgName
                        , fieldType
                        , fieldName
                        , isNullable = input.isNullable
                        }
                  , fieldName
                  , fieldType
                  , boxedJavaType = value.boxedJavaType
                  , codecRef = value.codecRef
                  , imports = value.imports
                  , dims =
                      Deps.Prelude.Optional.fold
                        Deps.Sdk.Project.ArraySettings
                        input.value.arraySettings
                        Natural
                        ( \(arr : Deps.Sdk.Project.ArraySettings) ->
                            arr.dimensionality
                        )
                        0
                  , isNullable = input.isNullable
                  , elementIsNullable =
                      Deps.Prelude.Optional.fold
                        Deps.Sdk.Project.ArraySettings
                        input.value.arraySettings
                        Bool
                        ( \(arr : Deps.Sdk.Project.ArraySettings) ->
                            arr.elementIsNullable
                        )
                        False
                  , needsCustomTypeImport = value.needsCustomTypeImport
                  }
          )
          ( Sdk.Compiled.nest
              Value.Output
              input.pgName
              (Value.run config input.value)
          )

in  Algebra.module Input Output run
