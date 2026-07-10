-- Renders the Statement interface method implementations for a result-returning statement.
-- Produces the methods without any surrounding indentation; splice site must indent.
let Sdk = ../Deps/Sdk.dhall

let Params = { decodeMethod : Text, resultTypeName : Text }

in  Sdk.Sigs.template
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
