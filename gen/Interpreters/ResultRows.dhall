let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Member = ./Member.dhall

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
                              let nullDoc =
                                    if    ic.value.isNullable
                                    then  " Nullable."
                                    else  ""

                              in  ''
                                  /**
                                   * Maps to the {@code ${ic.value.pgName}} result-set column.${nullDoc}
                                   */
                                  ${ic.value.fieldType} ${ic.value.fieldName}''
                          )
                          indexedColumns

                  let mkDecodeExpr =
                        \(ic : { index : Natural, value : Member.Output }) ->
                          let colIdx = Natural/show (ic.index + 1)

                          in  if    ic.value.useCodec
                              then  let elemSuffix =
                                          if    ic.value.elementIsOptional
                                          then  ".stream().map(Optional::ofNullable).toList()"
                                          else  ""

                                    in  if    ic.value.isOptional
                                        then  ''
                                              String ${ic.value.fieldName}Str = rs.getString(${colIdx});
                                              ${ic.value.fieldType} ${ic.value.fieldName} = Optional.ofNullable(${ic.value.fieldName}Str != null ? ${ic.value.codecRef}.decodeInTextFromString(${ic.value.fieldName}Str)${elemSuffix} : null);''
                                        else  if ic.value.isNullable
                                        then  ''
                                              String ${ic.value.fieldName}Str = rs.getString(${colIdx});
                                              ${ic.value.fieldType} ${ic.value.fieldName} = ${ic.value.fieldName}Str != null ? ${ic.value.codecRef}.decodeInTextFromString(${ic.value.fieldName}Str)${elemSuffix} : null;''
                                        else  "${ic.value.fieldType} ${ic.value.fieldName} = ${ic.value.codecRef}.decodeInTextFromString(rs.getString(${colIdx}))${elemSuffix};"
                              else  if ic.value.isDateType
                              then  if    ic.value.isOptional
                                    then  ''
                                          Date ${ic.value.fieldName}Sql = rs.getDate(${colIdx});
                                          ${ic.value.fieldType} ${ic.value.fieldName} = Optional.ofNullable(${ic.value.fieldName}Sql != null ? ${ic.value.fieldName}Sql.toLocalDate() : null);''
                                    else  if ic.value.isNullable
                                    then  ''
                                          Date ${ic.value.fieldName}Sql = rs.getDate(${colIdx});
                                          LocalDate ${ic.value.fieldName} = ${ic.value.fieldName}Sql != null ? ${ic.value.fieldName}Sql.toLocalDate() : null;''
                                    else  "LocalDate ${ic.value.fieldName} = rs.getDate(${colIdx}).toLocalDate();"
                              else  if ic.value.isOptional
                              then  if    ic.value.isJdbcPrimitive
                                    then  "${ic.value.fieldType} ${ic.value.fieldName} = Optional.ofNullable((${ic.value.boxedJavaType}) rs.getObject(${colIdx}));"
                                    else  "${ic.value.fieldType} ${ic.value.fieldName} = Optional.ofNullable(rs.${ic.value.jdbcGetter}(${colIdx}));"
                              else  if     ic.value.isNullable
                                       &&  ic.value.isJdbcPrimitive
                              then  "${ic.value.fieldType} ${ic.value.fieldName} = (${ic.value.fieldType}) rs.getObject(${colIdx});"
                              else  "${ic.value.fieldType} ${ic.value.fieldName} = rs.${ic.value.jdbcGetter}(${colIdx});"

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
