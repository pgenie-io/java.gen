let Algebra = ./Algebra/package.dhall

let Params = { packageName : Text, content : Text }

in  Algebra.module
      Params
      ( \(params : Params) ->
          ''
          package ${params.packageName}.statements;

          import ${params.packageName}.Statement;
          import ${params.packageName}.codecs.Jdbc;
          import ${params.packageName}.types.*;

          ${params.content}
          ''
      )
