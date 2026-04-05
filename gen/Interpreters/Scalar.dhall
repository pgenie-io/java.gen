let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Primitive = ./Primitive.dhall

let Input = Model.Scalar

let Output = Primitive.Output

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        merge
          { Primitive = Primitive.run config
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
                      , pgCastSuffix = "::${pgName}"
                      , testDefaultLiteral = "null"
                      }
          }
          input

in  Algebra.module Input Output run
