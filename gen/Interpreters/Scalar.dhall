let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Primitive = ./Primitive.dhall

let Input = Model.Scalar

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , useCodec : Bool
      , isDateType : Bool
      , isJdbcPrimitive : Bool
      , jdbcSetter : Text
      , jdbcGetter : Text
      , sqlTypesConstant : Text
      , pgCastSuffix : Text
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
                  ( \(p : Primitive.Output) ->
                      { javaType = p.javaType
                      , boxedJavaType = p.boxedJavaType
                      , codecRef = p.codecRef
                      , useCodec = p.useCodec
                      , isDateType = p.isDateType
                      , isJdbcPrimitive = p.isJdbcPrimitive
                      , jdbcSetter = p.jdbcSetter
                      , jdbcGetter = p.jdbcGetter
                      , sqlTypesConstant = p.sqlTypesConstant
                      , pgCastSuffix = ""
                      , testDefaultLiteral = p.testDefaultLiteral
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
                      , useCodec = True
                      , isDateType = False
                      , isJdbcPrimitive = False
                      , jdbcSetter = ""
                      , jdbcGetter = ""
                      , sqlTypesConstant = ""
                      , pgCastSuffix = "::public.${pgName}"
                      , testDefaultLiteral = "null"
                      }
          }
          input

in  Algebra.module Input Output run
