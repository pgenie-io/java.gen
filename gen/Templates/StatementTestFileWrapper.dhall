let Algebra = ./Algebra/package.dhall

let Params = { packageName : Text, content : Text }

in  Algebra.module
      Params
      ( \(params : Params) ->
          ''
          package ${params.packageName}.statements;

          import static org.junit.jupiter.api.Assertions.*;

          import ${params.packageName}.AbstractDatabaseIT;
          import ${params.packageName}.types.*;
          import java.sql.SQLException;
          import java.time.*;
          import org.junit.jupiter.api.Test;

          ${params.content}
          ''
      )
