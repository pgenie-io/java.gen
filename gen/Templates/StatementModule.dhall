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
      }

in  Algebra.module
      Params
      ( \(params : Params) ->
          let importPreparedStatement =
                ''
                import java.sql.PreparedStatement;
                ''

          let importResultSet =
                ''
                import java.sql.ResultSet;
                ''

          let importSqlException =
                ''
                import java.sql.SQLException;
                ''

          let importDate =
                if    params.hasDateParam || params.hasDateResult
                then  ''
                      import java.sql.Date;
                      ''
                else  ""

          let importTypes =
                if    params.hasNullableJdbcParam || params.hasDateParam
                then  ''
                      import java.sql.Types;
                      ''
                else  ""

          let importTimeAll =
                if    params.hasDateParam || params.hasDateResult
                then  ''
                      import java.time.*;
                      ''
                else  ""

          let importCodec =
                if    params.hasCodecParam
                then  ''
                      import io.codemine.java.postgresql.codecs.Codec;
                      ''
                else  ""

          let importArrayList =
                if    params.needsArrayListImport
                then  ''
                      import java.util.ArrayList;
                      ''
                else  ""

          let importList =
                if    params.hasResultType
                then  ''
                      import java.util.List;
                      ''
                else  ""

          in      importPreparedStatement
              ++  importResultSet
              ++  importSqlException
              ++  importDate
              ++  importTypes
              ++  importTimeAll
              ++  importCodec
              ++  "\n"
              ++  importArrayList
              ++  importList
              ++  ( if        params.needsArrayListImport
                          ||  params.hasResultType && True
                    then  "\n"
                    else  ""
                  )
              ++  params.docComment
              ++  "\n"
              ++  "public record "
              ++  params.typeName
              ++  ''
                  (
                  ''
              ++  params.paramFieldList
              ++  ''
                  )
                  ''
              ++  "        implements Statement<"
              ++  params.resultTypeName
              ++  ''
                  > {
                  ''
              ++  "\n"
              ++  ( if    params.hasResultType
                    then      ''
                                  // -------------------------------------------------------------------------
                              ''
                          ++  ''
                                  // Result type
                              ''
                          ++  ''
                                  // -------------------------------------------------------------------------
                              ''
                          ++  params.typeDecls
                          ++  "\n\n"
                    else  ""
                  )
              ++  ''
                      // -------------------------------------------------------------------------
                  ''
              ++  ''
                      // Statement implementation
                  ''
              ++  ''
                      // -------------------------------------------------------------------------
                  ''
              ++  params.statementImpl
              ++  "\n"
              ++  "}"
      )
