let Algebra = ./Algebra/package.dhall

let Params = { packageName : Text, content : Text }

in  Algebra.module
      Params
      ( \(params : Params) ->
          ''
          package ${params.packageName}.types;

          ${params.content}
          ''
      )
