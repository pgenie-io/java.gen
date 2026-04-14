let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Primitive = ./Primitive.dhall

let Input = Model.Scalar

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , imports : List Text
      , isDateType : Bool
      , jdbcSetter : Text
      , sqlTypesConstant : Text
      , pgCastSuffix : Optional Text
      , needsCustomTypeImport : Bool
      , testDefaultLiteral : Text
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        merge
          { Primitive =
              \(primitive : Model.Primitive) ->
                Sdk.Compiled.map
                  Primitive.Output
                  Output
                  ( \(primitive : Primitive.Output) ->
                          primitive
                      /\  { pgCastSuffix = None Text
                          , needsCustomTypeImport = False
                          }
                  )
                  (Primitive.run config primitive)
          , Custom =
              \(name : Model.Name) ->
                let typeName = Deps.CodegenKit.Name.toTextInPascal name

                let pgName = Deps.CodegenKit.Name.toTextInSnake name

                in  Sdk.Compiled.ok
                      Output
                      { javaType = typeName
                      , boxedJavaType = typeName
                      , codecRef = "${typeName}.CODEC"
                      , imports = [] : List Text
                      , isDateType = False
                      , jdbcSetter = ""
                      , sqlTypesConstant = ""
                      , pgCastSuffix = Some "::${pgName}"
                      , needsCustomTypeImport = True
                      , testDefaultLiteral = "null"
                      }
          }
          input

in  Algebra.module Input Output run
