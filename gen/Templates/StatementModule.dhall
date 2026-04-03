let Algebra = ./Algebra/package.dhall

let Deps = ../Deps/package.dhall

let Params =
      { typeName : Text
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

in  Algebra.module
      Params
      ( \(params : Params) ->
          let sqlImports =
                  [ "import java.sql.PreparedStatement;"
                  , "import java.sql.ResultSet;"
                  , "import java.sql.SQLException;"
                  ]
                # ( if    params.hasDateParam || params.hasDateResult
                    then  [ "import java.sql.Date;" ]
                    else  [] : List Text
                  )
                # ( if    params.hasNullableJdbcParam || params.hasDateParam
                    then  [ "import java.sql.Types;" ]
                    else  [] : List Text
                  )

          let timeImports =
                if    params.hasDateParam || params.hasDateResult
                then  [ "import java.time.*;" ]
                else  [] : List Text

          let codecImports =
                if    params.hasCodecParam
                then  [ "import io.codemine.java.postgresql.codecs.Codec;" ]
                else  [] : List Text

          let utilImports =
                  ( if    params.needsArrayListImport
                    then  [ "import java.util.ArrayList;" ]
                    else  [] : List Text
                  )
                # ( if    params.hasResultType
                    then  [ "import java.util.List;" ]
                    else  [] : List Text
                  )
                # ( if    params.hasOptionalFields
                    then  [ "import java.util.Optional;" ]
                    else  [] : List Text
                  )

          let allImportGroups =
                  [ Deps.Prelude.Text.concatSep "\n" sqlImports ]
                # ( if    Deps.Prelude.List.null Text timeImports
                    then  [] : List Text
                    else  [ Deps.Prelude.Text.concatSep "\n" timeImports ]
                  )
                # ( if    Deps.Prelude.List.null Text codecImports
                    then  [] : List Text
                    else  [ Deps.Prelude.Text.concatSep "\n" codecImports ]
                  )
                # ( if    Deps.Prelude.List.null Text utilImports
                    then  [] : List Text
                    else  [ Deps.Prelude.Text.concatSep "\n" utilImports ]
                  )

          let imports = Deps.Prelude.Text.concatSep "\n\n" allImportGroups

          in      imports
              ++  "\n\n"
              ++  params.docComment
              ++  ''

                  public record ${params.typeName}(
                  ''
              ++  "        "
              ++  Deps.Lude.Extensions.Text.indentNonEmpty
                    8
                    params.paramFieldList
              ++  ''
                  )
                          implements Statement<${params.resultTypeName}> {

                  ''
              ++  ( if    params.hasResultType
                    then      ''
                                  // -------------------------------------------------------------------------
                                  // Result type
                                  // -------------------------------------------------------------------------
                              ''
                          ++  "    "
                          ++  Deps.Lude.Extensions.Text.indentNonEmpty
                                4
                                params.typeDecls
                          ++  "\n\n"
                    else  ""
                  )
              ++  ''
                      // -------------------------------------------------------------------------
                      // Statement implementation
                      // -------------------------------------------------------------------------
                  ''
              ++  "    "
              ++  Deps.Lude.Extensions.Text.indentNonEmpty
                    4
                    params.statementImpl
              ++  ''

                  }''
      )
