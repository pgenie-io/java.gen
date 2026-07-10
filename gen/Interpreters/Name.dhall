let ResolvedTarget = ../ResolvedTarget.dhall

let Sdk = ../Deps/Sdk.dhall

let Contract = ../Deps/Contract.dhall

let Lude = ../Deps/Lude.dhall

let Input = Contract.Name

let Output = { fieldName : Text }

let replaceTextIfEquals =
    -- Text/equal is not available in this environment. We get full-string
    -- equality out of the substring-based Text/replace by wrapping both sides
    -- in a sentinel ("|", which cannot occur in an identifier): "|target|" is a
    -- substring of "|original|" only when target == original, so the inner
    -- replace fires exactly on an exact match. The outer replace strips the
    -- sentinels back out.
      \(target : Text) ->
      \(replacement : Text) ->
      \(original : Text) ->
        let replacedWithSentinels =
              Text/replace "|${target}|" "|${replacement}|" "|${original}|"

        let replacedSansSentinels = Text/replace "|" "" replacedWithSentinels

        in  replacedSansSentinels

let replaceTextIfInList
    : List Text -> Text -> Text -> Text
    = \(candidates : List Text) ->
      \(replacement : Text) ->
        List/fold
          Text
          candidates
          Text
          (\(candidate : Text) -> replaceTextIfEquals candidate replacement)

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

let escapeJavaKeyword
    : Text -> Text
    = \(text : Text) -> replaceTextIfInList javaKeywords (text ++ "_") text

let run =
      \(config : ResolvedTarget.Type) ->
      \(input : Input) ->
        let fieldName = escapeJavaKeyword input.inCamelCase

        in  Lude.Compiled.ok Output { fieldName }

in  Sdk.Sigs.Interpreter.module ResolvedTarget.Type Input Output run
