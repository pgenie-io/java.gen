let ImportSet = ../Structures/ImportSet.dhall

let InterpreterConfig = ../InterpreterConfig.dhall

let Sdk = ../Deps/Sdk.dhall

let Lude = ../Deps/Lude.dhall

let Model = ../Deps/Contract.dhall

let Primitive = ./Primitive.dhall

let Input = Model.Scalar

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , imports : ImportSet.Type
      , pgCastSuffix : Optional Text
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
      }

let run =
      \(config : InterpreterConfig.Type) ->
      \(input : Input) ->
        merge
          { Primitive =
              \(primitive : Model.Primitive) ->
                Lude.Compiled.map
                  Primitive.Output
                  Output
                  ( \(primitive : Primitive.Output) ->
                      primitive /\ { pgCastSuffix = None Text }
                  )
                  (Primitive.run config primitive)
          , Custom =
              \(name : Model.Name) ->
                let typeName = name.inPascalCase

                let pgName = name.inSnakeCase

                let codecRef = "${typeName}.CODEC"

                in  Lude.Compiled.ok
                      Output
                      { javaType = typeName
                      , boxedJavaType = typeName
                      , codecRef
                      , imports = ImportSet.customTypes
                      , pgCastSuffix = Some "::${pgName}"
                      , testDefaultLiteral =
                          "${codecRef}.toAgnostic().random(new java.util.Random(0L), 0)"
                      , testRandomLiteral =
                          "${codecRef}.toAgnostic().random(new java.util.Random(), 0)"
                      }
          }
          input

in  Sdk.Sigs.Interpreter.module InterpreterConfig.Type Input Output run
