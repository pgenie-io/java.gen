let Deps = ../Deps/package.dhall

let ResolvedTarget = ../ResolvedTarget.dhall

let Prelude = Deps.Prelude

let Sdk = Deps.Sdk

let Lude = Deps.Lude

let Compiled = Lude.Compiled

let Input = Deps.Contract.QueryFragments

let Output
    : Type
    = { mkSqlExp : List Text -> Text, docComment : Text }

let escapeJavaString
    : Text -> Text
    = Prelude.Function.composeList
        Text
        [ Prelude.Text.replace "\\" "\\\\", Prelude.Text.replace "\"" "\\\"" ]

let renderSqlExp
    : Deps.Contract.QueryFragments -> List Text -> Text
    = \(fragments : Deps.Contract.QueryFragments) ->
      \(castSuffixes : List Text) ->
        Prelude.Text.concatMap
          Deps.Contract.QueryFragment
          ( \(queryFragment : Deps.Contract.QueryFragment) ->
              merge
                { Sql = escapeJavaString
                , Var =
                    \(var : Deps.Contract.Var) ->
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
    : Deps.Contract.QueryFragments -> Text
    = Prelude.Text.concatMap
        Deps.Contract.QueryFragment
        ( \(queryFragment : Deps.Contract.QueryFragment) ->
            merge
              { Sql = Prelude.Function.identity Text
              , Var = \(var : Deps.Contract.Var) -> "\$${var.rawName}"
              }
              queryFragment
        )

let run =
      \(config : ResolvedTarget.Type) ->
      \(input : Input) ->
        Compiled.ok
          Output
          { mkSqlExp = renderSqlExp input, docComment = renderDocComment input }

in  Deps.Sdk.Sigs.Interpreter.module ResolvedTarget.Type Input Output run
