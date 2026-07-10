let InterpreterConfig = ../InterpreterConfig.dhall

let Prelude = ../Deps/Prelude.dhall

let Sdk = ../Deps/Sdk.dhall

let Lude = ../Deps/Lude.dhall

let Contract = ../Deps/Contract.dhall

let Compiled = Lude.Compiled

let Input = Contract.QueryFragments

let Output
    : Type
    = { mkSqlExp : List Text -> Text, docComment : Text }

let escapeJavaString
    : Text -> Text
    = Prelude.Function.composeList
        Text
        [ Prelude.Text.replace "\\" "\\\\", Prelude.Text.replace "\"" "\\\"" ]

let renderSqlExp
    : Contract.QueryFragments -> List Text -> Text
    = \(fragments : Contract.QueryFragments) ->
      \(castSuffixes : List Text) ->
        Prelude.Text.concatMap
          Contract.QueryFragment
          ( \(queryFragment : Contract.QueryFragment) ->
              merge
                { Sql = escapeJavaString
                , Var =
                    \(var : Contract.Var) ->
                      let suffix =
                            Prelude.Optional.fold
                              Text
                              ( Prelude.List.index
                                  var.paramIndex
                                  Text
                                  castSuffixes
                              )
                              Text
                              (\(s : Text) -> s)
                              ""

                      in  "?${suffix}"
                }
                queryFragment
          )
          fragments

let renderDocComment
    : Contract.QueryFragments -> Text
    = Prelude.Text.concatMap
        Contract.QueryFragment
        ( \(queryFragment : Contract.QueryFragment) ->
            merge
              { Sql = Prelude.Function.identity Text
              , Var = \(var : Contract.Var) -> "\$${var.rawName}"
              }
              queryFragment
        )

let run =
      \(config : InterpreterConfig.Type) ->
      \(input : Input) ->
        Compiled.ok
          Output
          { mkSqlExp = renderSqlExp input, docComment = renderDocComment input }

in  Sdk.Sigs.Interpreter.module InterpreterConfig.Type Input Output run
