let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Member = ./Member.dhall

let StatementModuleSub = ../Templates/StatementModule/package.dhall

let Input = Deps.Sdk.Project.ResultRows

let ExtraCtx = { sqlExp : Text, paramBindCode : Text }

let Output = ExtraCtx -> Text -> { statementImpl : Text, typeDecls : Text }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let compiledColumns =
              Deps.Typeclasses.Classes.Applicative.traverseList
                Deps.Sdk.Compiled.Type
                Deps.Sdk.Compiled.applicative
                Deps.Sdk.Project.Member
                Member.Output
                (Member.run config)
                ( Deps.Prelude.NonEmpty.toList
                    Deps.Sdk.Project.Member
                    input.columns
                )

        in  Deps.Sdk.Compiled.flatMap
              (List Member.Output)
              Output
              ( \(columns : List Member.Output) ->
                  let hasCodecDecode =
                        Deps.Prelude.List.any
                          Member.Output
                          (\(col : Member.Output) -> col.useCodec)
                          columns

                  let indexedColumns =
                        Deps.Prelude.List.indexed Member.Output columns

                  let columnFieldList =
                        Deps.Prelude.Text.concatMapSep
                          ''
                          ,
                          ''
                          { index : Natural, value : Member.Output }
                          ( \ ( ic
                              : { index : Natural, value : Member.Output }
                              ) ->
                              StatementModuleSub.ResultColumnField.run
                                { pgName = ic.value.pgName
                                , fieldType = ic.value.fieldType
                                , fieldName = ic.value.fieldName
                                , isNullable = ic.value.isNullable
                                }
                          )
                          indexedColumns

                  let mkDecodeExpr =
                        \(ic : { index : Natural, value : Member.Output }) ->
                          StatementModuleSub.ColDecodeStatement.run
                            { colIdx = Natural/show (ic.index + 1)
                            , fieldName = ic.value.fieldName
                            , fieldType = ic.value.fieldType
                            , boxedJavaType = ic.value.boxedJavaType
                            , useCodec = ic.value.useCodec
                            , codecRef = ic.value.codecRef
                            , elementIsOptional = ic.value.elementIsOptional
                            , isOptional = ic.value.isOptional
                            , isNullable = ic.value.isNullable
                            , isDateType = ic.value.isDateType
                            , isJdbcPrimitive = ic.value.isJdbcPrimitive
                            , jdbcGetter = ic.value.jdbcGetter
                            }

                  let decodeLines =
                        Deps.Prelude.Text.concatMapSep
                          "\n"
                          { index : Natural, value : Member.Output }
                          mkDecodeExpr
                          indexedColumns

                  let varRefs =
                        Deps.Prelude.Text.concatMapSep
                          ", "
                          Member.Output
                          (\(col : Member.Output) -> col.fieldName)
                          columns

                  let decodeBody =
                        if    hasCodecDecode
                        then  ''
                              try {
                                  ${Deps.Lude.Extensions.Text.indentNonEmpty
                                      4
                                      decodeLines}

                                  output.add(new OutputRow(${varRefs}));
                              } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                                  throw new IllegalStateException(e);
                              }''
                        else  ''
                              ${decodeLines}
                              output.add(new OutputRow(${varRefs}));''

                  in  Deps.Sdk.Compiled.ok
                        Output
                        ( \(ctx : ExtraCtx) ->
                          \(typeNameBase : Text) ->
                            let multipleResult =
                                  { typeDecls =
                                      ''
                                      /**
                                       * Result of the statement parameterised by {@link ${typeNameBase}}.
                                       */
                                      public static final class Output extends ArrayList<OutputRow> {
                                          Output() {}
                                      }

                                      /**
                                       * Row of {@link Output}.
                                       */
                                      public record OutputRow(
                                              ${Deps.Lude.Extensions.Text.indentNonEmpty
                                                  8
                                                  columnFieldList}) {}''
                                  , decodeMethod =
                                      ''
                                      @Override
                                      public Output decodeResultSet(ResultSet rs) throws SQLException {
                                          Output output = new Output();
                                          while (rs.next()) {
                                              ${Deps.Lude.Extensions.Text.indentNonEmpty
                                                  8
                                                  decodeBody}
                                          }
                                          return output;
                                      }''
                                  , resultTypeName = "${typeNameBase}.Output"
                                  }

                            let singleResult =
                                  let singleDecodeBody =
                                        if    hasCodecDecode
                                        then  ''
                                              try {
                                                  ${Deps.Lude.Extensions.Text.indentNonEmpty
                                                      4
                                                      decodeLines}

                                                  return new Output(${varRefs});
                                              } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                                                  throw new IllegalStateException(e);
                                              }''
                                        else  ''
                                              ${decodeLines}
                                              return new Output(${varRefs});''

                                  in  { typeDecls =
                                          ''
                                          /**
                                           * Result of the statement parameterised by {@link ${typeNameBase}}.
                                           */
                                          public record Output(
                                                  ${Deps.Lude.Extensions.Text.indentNonEmpty
                                                      8
                                                      columnFieldList}) {}''
                                      , decodeMethod =
                                          ''
                                          @Override
                                          public Output decodeResultSet(ResultSet rs) throws SQLException {
                                              rs.next();
                                              ${Deps.Lude.Extensions.Text.indentNonEmpty
                                                  4
                                                  singleDecodeBody}
                                          }''
                                      , resultTypeName =
                                          "${typeNameBase}.Output"
                                      }

                            let optionalResult =
                                  let optDecodeBody =
                                        if    hasCodecDecode
                                        then  ''
                                              try {
                                                  ${Deps.Lude.Extensions.Text.indentNonEmpty
                                                      4
                                                      decodeLines}

                                                  return new Output(${varRefs});
                                              } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                                                  throw new IllegalStateException(e);
                                              }''
                                        else  ''
                                              ${decodeLines}
                                              return new Output(${varRefs});''

                                  in  { typeDecls = singleResult.typeDecls
                                      , decodeMethod =
                                          ''
                                          @Override
                                          public Output decodeResultSet(ResultSet rs) throws SQLException {
                                              if (!rs.next()) {
                                                  return null;
                                              }
                                              ${Deps.Lude.Extensions.Text.indentNonEmpty
                                                  4
                                                  optDecodeBody}
                                          }''
                                      , resultTypeName =
                                          "${typeNameBase}.Output"
                                      }

                            let resolved =
                                  merge
                                    { Optional = optionalResult
                                    , Single = singleResult
                                    , Multiple = multipleResult
                                    }
                                    input.cardinality

                            in  { statementImpl =
                                    ''
                                    @Override
                                    public String sql() {
                                        return """
                                               ${Deps.Lude.Extensions.Text.indentNonEmpty
                                                   11
                                                   ctx.sqlExp}
                                               """;
                                    }

                                    @Override
                                    public void bindParams(PreparedStatement ps) throws SQLException {
                                        ${Deps.Lude.Extensions.Text.indentNonEmpty
                                            4
                                            ctx.paramBindCode}
                                    }

                                    @Override
                                    public boolean returnsRows() {
                                        return true;
                                    }

                                    ${resolved.decodeMethod}

                                    @Override
                                    public ${resolved.resultTypeName} decodeAffectedRows(long affectedRows) {
                                        throw new UnsupportedOperationException();
                                    }''
                                , typeDecls = resolved.typeDecls
                                }
                        )
              )
              compiledColumns

in  Algebra.module Input Output run
