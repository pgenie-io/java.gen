let Algebra = ../Algebras/Template.dhall

let Deps = ../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params =
      { packageName : Text
      , typeName : Text
      , queryName : Text
      , sqlDoc : Text
      , sqlExp : Text
      , srcPath : Text
      , paramBindCode : Text
      , paramFields : List Text
      , typeDecls : Text
      , statementImpl : Text
      , statementTypeArg : Text
      , extraImports : List Text
      , needsArrayListImport : Bool
      , hasResultType : Bool
      , hasOptionalFields : Bool
      , needsCustomTypeImport : Bool
      }

let someIf =
      \(V : Type) ->
      \(condition : Bool) ->
      \(v : V) ->
        if condition then Some v else None V

in  Algebra.module
      Params
      ( \(params : Params) ->
          let imports =
                Deps.Prelude.Text.concatMap
                  Text
                  ( \(import : Text) ->
                      ''
                      import ${import};
                      ''
                  )
                  (   Deps.Prelude.List.unpackOptionals
                        Text
                        [ Some "java.sql.PreparedStatement"
                        , Some "java.sql.ResultSet"
                        , Some "java.sql.SQLException"
                        , Some "java.time.*"
                        , Some "java.util.ArrayList"
                        , Some "java.util.List"
                        , Some "java.util.Optional"
                        , Some "io.codemine.java.postgresql.jdbc.Codec"
                        , Some "io.codemine.java.postgresql.jdbc.Statement"
                        ]
                    # params.extraImports
                    # Deps.Prelude.List.unpackOptionals
                        Text
                        [ someIf
                            Text
                            params.needsCustomTypeImport
                            "${params.packageName}.types.*"
                        ]
                  )

          let paramFieldList =
                Deps.Prelude.Text.concatSep
                  ''
                  ,
                  ''
                  params.paramFields

          let resultTypeSection =
                if    params.hasResultType
                then  ''

                      // -------------------------------------------------------------------------
                      // Result type
                      // -------------------------------------------------------------------------
                      ${params.typeDecls}
                      ''
                else  ""

          in  ''
              package ${params.packageName}.statements;

              ${imports}
              /**
               * Type-safe binding for the {@code ${params.queryName}} query.
               *
               * <h2>SQL Template</h2>
               *
               * <pre>{@code
               * ${Deps.Lude.Extensions.Text.prefixEachLine " * " params.sqlDoc}
               * }</pre>
               *
               * <h2>Source Path</h2> {@code ${params.srcPath}}
               *
               * <p>
               * Generated from SQL queries using the
               * <a href="https://pgenie.io">pGenie</a> code generator.
               */
              public record ${params.typeName}(
                      ${indent 8 paramFieldList})
                      implements Statement<${params.statementTypeArg}> {
                  ${indent 4 resultTypeSection}
                  // -------------------------------------------------------------------------
                  // Statement implementation
                  // -------------------------------------------------------------------------
                  @Override
                  public String sql() {
                      return """
                             ${indent 15 params.sqlExp}
                             """;
                  }

                  @Override
                  public void bindParams(PreparedStatement ps) throws SQLException {
                      ${indent 8 params.paramBindCode}
                  }

                  ${indent 4 params.statementImpl}
              }
              ''
      )
