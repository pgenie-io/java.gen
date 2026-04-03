let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Prelude = Deps.Prelude

let Sdk = Deps.Sdk

let Compiled = Sdk.Compiled

let Input = Deps.Sdk.Project.QueryFragments

let Output
    : Type
    = { mkSqlExp : List Text -> Text, docComment : Text }

let escapeJavaString
    : Text -> Text
    = Prelude.Function.composeList
        Text
        [ Prelude.Text.replace "\\" "\\\\", Prelude.Text.replace "\"" "\\\"" ]

let renderSqlExp
    : Deps.Sdk.Project.QueryFragments -> List Text -> Text
    = \(fragments : Deps.Sdk.Project.QueryFragments) ->
      \(castSuffixes : List Text) ->
        Prelude.Text.concatMap
          Deps.Sdk.Project.QueryFragment
          ( \(queryFragment : Deps.Sdk.Project.QueryFragment) ->
              merge
                { Sql = escapeJavaString
                , Var =
                    \(var : Deps.Sdk.Project.Var) ->
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
    : Deps.Sdk.Project.QueryFragments -> Text
    = Prelude.Text.concatMap
        Deps.Sdk.Project.QueryFragment
        ( \(queryFragment : Deps.Sdk.Project.QueryFragment) ->
            merge
              { Sql = Prelude.Function.identity Text
              , Var = \(var : Deps.Sdk.Project.Var) -> "\$${var.rawName}"
              }
              queryFragment
        )

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Compiled.ok
          Output
          { mkSqlExp = renderSqlExp input, docComment = renderDocComment input }

in  Algebra.module Input Output run
