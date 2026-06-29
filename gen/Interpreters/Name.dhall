let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Model = Deps.Sdk.Project

let Lude = Deps.Lude

let Input = Model.Name

let Output = { fieldName : Text }

let replaceIfEquals =
    -- Text/equal is not available in this environment. We get full-string
    -- equality out of the substring-based Text/replace by wrapping both sides
    -- in a sentinel ("|", which cannot occur in an identifier): "|target|" is a
    -- substring of "|original|" only when target == original, so the inner
    -- replace fires exactly on an exact match. The outer replace strips the
    -- sentinels back out.
      \(target : Text) ->
      \(replacement : Text) ->
      \(original : Text) ->
        Text/replace
          "|"
          ""
          ( Text/replace
              ("|" ++ target ++ "|")
              ("|" ++ replacement ++ "|")
              ("|" ++ original ++ "|")
          )

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

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let rawFieldName = input.inCamelCase

        let fieldName =
            -- Suffix the name with "_" if it collides with a Java keyword: each
            -- keyword that exactly matches the accumulator rewrites it to
            -- `kw ++ "_"`; at most one matches, and the result never matches a
            -- later keyword.
              List/fold
                Text
                javaKeywords
                Text
                ( \(kw : Text) ->
                  \(acc : Text) ->
                    replaceIfEquals kw (kw ++ "_") acc
                )
                rawFieldName

        in  Lude.Compiled.ok Output { fieldName }

in  Algebra.module Input Output run
