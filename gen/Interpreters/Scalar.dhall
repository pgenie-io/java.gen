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
      , imports : Deps.ImportSet.Struct
      , isDateType : Bool
      , jdbcSetter : Text
      , sqlTypesConstant : Text
      , pgCastSuffix : Optional Text
      , needsCustomTypeImport : Bool
      , testDefaultLiteral : Text
      , testLiteralIsNull : Bool
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

                let codecRef = "${typeName}.CODEC"

                in  Sdk.Compiled.ok
                      Output
                      { javaType = typeName
                      , boxedJavaType = typeName
                      , codecRef
                      , imports = Deps.ImportSet.empty
                      , isDateType = False
                      , jdbcSetter = ""
                      , sqlTypesConstant = ""
                      , pgCastSuffix = Some "::${pgName}"
                      , needsCustomTypeImport = True
                      , testDefaultLiteral =
                          "${codecRef}.toAgnostic().random(new java.util.Random(0L), 0)"
                      , testLiteralIsNull = False
                      }
          }
          input

in  Algebra.module Input Output run
