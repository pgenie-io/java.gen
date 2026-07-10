let ImportSet = ../Structures/ImportSet.dhall

let InterpreterConfig = ../InterpreterConfig.dhall

let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Model = ../Deps/Contract.dhall

let Templates = ../Templates/package.dhall

let Value = ./Value.dhall

let Name = ./Name.dhall

let Input = Model.Member

let Output =
      { fieldName : Text
      , fieldType : Text
      , pgName : Text
      , pgCastSuffix : Text
      , codecRef : Text
      , boxedJavaType : Text
      , rawCodecType : Text
      , columnField : Text
      , imports : ImportSet.Type
      , isNullable : Bool
      , isOptional : Bool
      , elementIsOptional : Bool
      , elementIsNullable : Bool
      , dims : Natural
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
      , testPresentLiteral : Text
      , testAbsentLiteral : Text
      }

let run =
      \(config : InterpreterConfig.Type) ->
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

                in  { fieldName
                    , fieldType
                    , pgName = input.pgName
                    , pgCastSuffix = value.pgCastSuffix
                    , codecRef = value.codecRef
                    , boxedJavaType = value.boxedJavaType
                    , rawCodecType = value.rawCodecType
                    , columnField =
                        Templates.ResultColumnField.run
                          { pgName = input.pgName
                          , fieldType
                          , fieldName
                          , isNullable = input.isNullable
                          }
                    , imports = value.imports
                    , isNullable = input.isNullable
                    , isOptional
                    , elementIsOptional = value.elementIsOptional
                    , elementIsNullable =
                        Prelude.Optional.fold
                          Model.ArraySettings
                          input.value.arraySettings
                          Bool
                          ( \(arr : Model.ArraySettings) ->
                              arr.elementIsNullable
                          )
                          False
                    , dims =
                        Prelude.Optional.fold
                          Model.ArraySettings
                          input.value.arraySettings
                          Natural
                          (\(arr : Model.ArraySettings) -> arr.dimensionality)
                          0
                    , testDefaultLiteral =
                        if    isOptional
                        then  "Optional.empty()"
                        else  value.testDefaultLiteral
                    , testRandomLiteral =
                        if    isOptional
                        then  "Optional.of(${value.testRandomLiteral})"
                        else  value.testRandomLiteral
                    , testPresentLiteral =
                        if    isOptional
                        then  "Optional.of(${value.testDefaultLiteral})"
                        else  value.testDefaultLiteral
                    , testAbsentLiteral =
                        if isOptional then "Optional.empty()" else "null"
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

in  Sdk.Sigs.Interpreter.module InterpreterConfig.Type Input Output run
