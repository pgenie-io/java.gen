let Algebra = ./Algebra/package.dhall

let Deps = ../Deps/package.dhall

let indent = Deps.Lude.Extensions.Text.indentNonEmpty

let Params =
      { packageName : Text
      , typeName : Text
      , docComment : Text
      , paramFieldList : Text
      , resultTypeName : Text
      , typeDecls : Text
      , statementImpl : Text
      , hasCodecParam : Bool
      , hasDateParam : Bool
      , hasNullableJdbcParam : Bool
      , needsArrayListImport : Bool
      , hasResultType : Bool
      , hasDateResult : Bool
      , hasCodecResult : Bool
      , hasOptionalFields : Bool
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
                  ( Deps.Prelude.List.unpackOptionals
                      Text
                      [ Some "java.sql.PreparedStatement"
                      , Some "java.sql.ResultSet"
                      , Some "java.sql.SQLException"
                      , someIf
                          Text
                          (params.hasDateParam || params.hasDateResult)
                          "java.sql.Date"
                      , someIf
                          Text
                          (params.hasNullableJdbcParam || params.hasDateParam)
                          "java.sql.Types"
                      , someIf
                          Text
                          (params.hasDateParam || params.hasDateResult)
                          "java.time.*"
                      , someIf
                          Text
                          params.needsArrayListImport
                          "java.util.ArrayList"
                      , someIf Text params.hasResultType "java.util.List"
                      , someIf
                          Text
                          params.hasOptionalFields
                          "java.util.Optional"
                      , someIf
                          Text
                          params.hasCodecParam
                          "io.codemine.java.postgresql.codecs.Codec"
                      , Some "${params.packageName}.Statement"
                      , Some "${params.packageName}.codecs.Jdbc"
                      , Some "${params.packageName}.types.*"
                      ]
                  )

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
              ${params.docComment}
              public record ${params.typeName}(
                      ${indent 8 params.paramFieldList})
                      implements Statement<${params.resultTypeName}> {

                  ${indent
                      4
                      resultTypeSection}// -------------------------------------------------------------------------
                  // Statement implementation
                  // -------------------------------------------------------------------------
                  ${indent 4 params.statementImpl}
              }
              ''
      )
