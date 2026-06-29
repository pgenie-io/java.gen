let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Model = Deps.Sdk.Project

let Lude = Deps.Lude

let Input = Model.Name

let Output = { fieldName : Text }

let isEmpty =
    -- Text/equal is not available in this environment, so string equality is
    -- encoded in "Text land": "x" stands for true and "" for false. This lets us
    -- compute the keyword suffix without ever producing a Bool.
      \(text : Text) -> Text/replace "xx" "" ("x" ++ Text/replace text "x" text)

let equals =
      \(t1 : Text) ->
      \(t2 : Text) ->
        isEmpty (Text/replace t1 "" t2 ++ Text/replace t2 "" t1)

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

let keywordSuffix =
    -- "_" if the name collides with a Java keyword, otherwise "". The fold yields
    -- the "x" marker for the (at most one) matching keyword, which we map to "_".
      \(name : Text) ->
        Text/replace
          "x"
          "_"
          ( List/fold
              Text
              javaKeywords
              Text
              (\(kw : Text) -> \(acc : Text) -> acc ++ equals kw name)
              ""
          )

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let rawFieldName = input.inCamelCase

        let fieldName = rawFieldName ++ keywordSuffix rawFieldName

        in  Lude.Compiled.ok Output { fieldName }

in  Algebra.module Input Output run
