let Deps = ../Deps/package.dhall

let ImportSet = ../Structures/ImportSet.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Lude = Deps.Lude

let Model = Deps.Sdk.Project

let Primitive = ./Primitive.dhall

let Input = Model.Scalar

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , imports : ImportSet.Type
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
                Lude.Compiled.map
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
                let typeName = name.inPascalCase

                let pgName = name.inSnakeCase

                let codecRef = "${typeName}.CODEC"

                in  Lude.Compiled.ok
                      Output
                      { javaType = typeName
                      , boxedJavaType = typeName
                      , codecRef
                      , imports = ImportSet.empty
                      , pgCastSuffix = Some "::${pgName}"
                      , needsCustomTypeImport = True
                      , testDefaultLiteral =
                          "${codecRef}.toAgnostic().random(new java.util.Random(0L), 0)"
                      }
          }
          input

in  Algebra.module Input Output run
