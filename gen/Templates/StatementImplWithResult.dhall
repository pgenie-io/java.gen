-- Renders the Statement interface method implementations for a result-returning statement.
-- Produces the methods without any surrounding indentation; splice site must indent.
let Algebra = ../Algebras/Template.dhall

let Deps = ../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params = { decodeMethod : Text, resultTypeName : Text }

in  Algebra.module
      Params
      ( \(p : Params) ->
          ''
          @Override
          public boolean returnsRows() {
              return true;
          }

          ${p.decodeMethod}

          @Override
          public ${p.resultTypeName} decodeAffectedRows(long affectedRows) {
              throw new UnsupportedOperationException();
          }''
      )
