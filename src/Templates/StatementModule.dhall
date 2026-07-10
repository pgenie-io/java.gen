let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let ImportSet = ../Structures/ImportSet.dhall

let indent = Lude.Text.indentNonEmpty

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
      , extraImports : ImportSet.Type
      , hasResultType : Bool
      }

in  Sdk.Sigs.template
      Params
      ( \(params : Params) ->
          let imports =
                Prelude.Text.concatMap
                  Text
                  ( \(import : Text) ->
                      ''
                      import ${import};
                      ''
                  )
                  (   [ "java.sql.PreparedStatement"
                      , "java.sql.ResultSet"
                      , "java.sql.SQLException"
                      , "java.time.*"
                      , "java.util.ArrayList"
                      , "java.util.List"
                      , "java.util.Optional"
                      , "io.codemine.java.postgresql.jdbc.Codec"
                      , "io.codemine.java.postgresql.jdbc.Statement"
                      ]
                    # ImportSet.toImportLines
                        params.extraImports
                        params.packageName
                  )

          let paramFieldList =
                Prelude.Text.concatSep
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
               * ${Lude.Text.prefixEachLine " * " params.sqlDoc}
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
