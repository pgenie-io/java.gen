let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Model = Deps.Sdk.Project

let Lude = Deps.Lude

let Input = Model.Name

let Output = { fieldName : Text }

let javaKeywords
    : List Text
    = [ "abstract"
      , "assert"
      , "boolean"
      , "break"
      , "byte"
      , "case"
      , "catch"
      , "char"
      , "class"
      , "const"
      , "continue"
      , "default"
      , "do"
      , "double"
      , "else"
      , "enum"
      , "extends"
      , "final"
      , "finally"
      , "float"
      , "for"
      , "goto"
      , "if"
      , "implements"
      , "import"
      , "instanceof"
      , "int"
      , "interface"
      , "long"
      , "module"
      , "native"
      , "new"
      , "package"
      , "private"
      , "protected"
      , "public"
      , "record"
      , "return"
      , "sealed"
      , "short"
      , "static"
      , "strictfp"
      , "super"
      , "switch"
      , "synchronized"
      , "this"
      , "throw"
      , "throws"
      , "transient"
      , "try"
      , "void"
      , "volatile"
      , "while"
      , "exports"
      , "open"
      , "requires"
      , "transitive"
      , "uses"
      , "provides"
      , "with"
      , "var"
      , "yield"
      , "true"
      , "false"
      , "null"
      ]

let isJavaKeyword
    : Input -> Bool
    = \(name : Input) ->
        Deps.Prelude.List.any
          Text
          (\(kw : Text) -> Text/equal kw name.inCamelCase)
          javaKeywords

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let rawFieldName = input.inCamelCase

        let fieldName =
              if isJavaKeyword input then "${rawFieldName}_" else rawFieldName

        in  Lude.Compiled.ok Output { fieldName }

in  Algebra.module Input Output run
