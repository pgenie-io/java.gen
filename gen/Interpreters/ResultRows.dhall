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

                  let columnFieldDecls =
                        Deps.Prelude.Text.concatMap
                          { index : Natural, value : Member.Output }
                          ( \ ( ic
                              : { index : Natural, value : Member.Output }
                              ) ->
                              let nullDoc =
                                    if    ic.value.isNullable
                                    then  " Nullable."
                                    else  ""

                              in      ''
                                                  /**
                                      ''
                                  ++  "             * Maps to the {@code "
                                  ++  ic.value.pgName
                                  ++  "} result-set column."
                                  ++  nullDoc
                                  ++  "\n"
                                  ++  ''
                                                   */
                                      ''
                                  ++  "            "
                                  ++  ic.value.fieldType
                                  ++  " "
                                  ++  ic.value.fieldName
                          )
                          ( Deps.Prelude.List.map
                              { index : Natural, value : Member.Output }
                              { index : Natural, value : Member.Output }
                              ( \ ( ic
                                  : { index : Natural, value : Member.Output }
                                  ) ->
                                  ic
                              )
                              indexedColumns
                          )

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

                              in      ''
                                                  /**
                                      ''
                                  ++  "             * Maps to the {@code "
                                  ++  ic.value.pgName
                                  ++  "} result-set column."
                                  ++  nullDoc
                                  ++  "\n"
                                  ++  ''
                                                   */
                                      ''
                                  ++  "            "
                                  ++  ic.value.fieldType
                                  ++  " "
                                  ++  ic.value.fieldName
                          )
                          indexedColumns

                  let mkDecodeExpr =
                        \(ic : { index : Natural, value : Member.Output }) ->
                          let colIdx = Natural/show (ic.index + 1)

                          in  if    ic.value.useCodec
                              then  if    ic.value.isNullable
                                    then      "                String "
                                          ++  ic.value.fieldName
                                          ++  "Str = rs.getString("
                                          ++  colIdx
                                          ++  ''
                                              );
                                              ''
                                          ++  "                "
                                          ++  ic.value.fieldType
                                          ++  " "
                                          ++  ic.value.fieldName
                                          ++  " = "
                                          ++  ic.value.fieldName
                                          ++  "Str != null ? "
                                          ++  ic.value.codecRef
                                          ++  ".decodeInTextFromString("
                                          ++  ic.value.fieldName
                                          ++  "Str) : null;"
                                    else      "                "
                                          ++  ic.value.fieldType
                                          ++  " "
                                          ++  ic.value.fieldName
                                          ++  " = "
                                          ++  ic.value.codecRef
                                          ++  ".decodeInTextFromString(rs.getString("
                                          ++  colIdx
                                          ++  "));"
                              else  if ic.value.isDateType
                              then  if    ic.value.isNullable
                                    then      "                Date "
                                          ++  ic.value.fieldName
                                          ++  "Sql = rs.getDate("
                                          ++  colIdx
                                          ++  ''
                                              );
                                              ''
                                          ++  "                LocalDate "
                                          ++  ic.value.fieldName
                                          ++  " = "
                                          ++  ic.value.fieldName
                                          ++  "Sql != null ? "
                                          ++  ic.value.fieldName
                                          ++  "Sql.toLocalDate() : null;"
                                    else      "                LocalDate "
                                          ++  ic.value.fieldName
                                          ++  " = rs.getDate("
                                          ++  colIdx
                                          ++  ").toLocalDate();"
                              else  if     ic.value.isNullable
                                       &&  ic.value.isJdbcPrimitive
                              then      "                "
                                    ++  ic.value.fieldType
                                    ++  " "
                                    ++  ic.value.fieldName
                                    ++  " = ("
                                    ++  ic.value.fieldType
                                    ++  ") rs.getObject("
                                    ++  colIdx
                                    ++  ");"
                              else      "                "
                                    ++  ic.value.fieldType
                                    ++  " "
                                    ++  ic.value.fieldName
                                    ++  " = rs."
                                    ++  ic.value.jdbcGetter
                                    ++  "("
                                    ++  colIdx
                                    ++  ");"

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
                        then      ''
                                              try {
                                  ''
                              ++  decodeLines
                              ++  "\n"
                              ++  "                output.add(new OutputRow("
                              ++  varRefs
                              ++  ''
                                  ));
                                  ''
                              ++  ''
                                              } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                                  ''
                              ++  ''
                                                  throw new IllegalStateException(e);
                                  ''
                              ++  "            }"
                        else      decodeLines
                              ++  "\n"
                              ++  "                output.add(new OutputRow("
                              ++  varRefs
                              ++  "));"

                  in  Deps.Sdk.Compiled.ok
                        Output
                        ( \(ctx : ExtraCtx) ->
                          \(typeNameBase : Text) ->
                            let multipleResult =
                                  { typeDecls =
                                          ''
                                              /**
                                          ''
                                      ++  "     * Result of the statement parameterised by {@link "
                                      ++  typeNameBase
                                      ++  ''
                                          }.
                                          ''
                                      ++  ''
                                               */
                                          ''
                                      ++  ''
                                              public static final class Output extends ArrayList<OutputRow> {
                                          ''
                                      ++  "\n"
                                      ++  ''
                                                  Output() {
                                          ''
                                      ++  ''
                                                  }
                                          ''
                                      ++  ''
                                              }
                                          ''
                                      ++  "\n"
                                      ++  ''
                                              /**
                                          ''
                                      ++  ''
                                               * Row of {@link Output}.
                                          ''
                                      ++  ''
                                               */
                                          ''
                                      ++  ''
                                              public record OutputRow(
                                          ''
                                      ++  columnFieldList
                                      ++  ''
                                          ) {
                                          ''
                                      ++  "\n"
                                      ++  "    }"
                                  , decodeMethod =
                                          ''
                                              @Override
                                          ''
                                      ++  ''
                                              public Output decodeResultSet(ResultSet rs) throws SQLException {
                                          ''
                                      ++  ''
                                                  Output output = new Output();
                                          ''
                                      ++  ''
                                                  while (rs.next()) {
                                          ''
                                      ++  decodeBody
                                      ++  "\n"
                                      ++  ''
                                                  }
                                          ''
                                      ++  ''
                                                  return output;
                                          ''
                                      ++  "    }"
                                  , resultTypeName = typeNameBase ++ ".Output"
                                  }

                            let singleResult =
                                  { typeDecls =
                                          ''
                                              /**
                                          ''
                                      ++  "     * Result of the statement parameterised by {@link "
                                      ++  typeNameBase
                                      ++  ''
                                          }.
                                          ''
                                      ++  ''
                                               */
                                          ''
                                      ++  ''
                                              public record Output(
                                          ''
                                      ++  columnFieldList
                                      ++  ''
                                          ) {
                                          ''
                                      ++  "\n"
                                      ++  "    }"
                                  , decodeMethod =
                                          ''
                                              @Override
                                          ''
                                      ++  ''
                                              public Output decodeResultSet(ResultSet rs) throws SQLException {
                                          ''
                                      ++  ''
                                                  rs.next();
                                          ''
                                      ++  ( let singleDecodeLines =
                                                  Deps.Prelude.Text.concatMapSep
                                                    "\n"
                                                    { index : Natural
                                                    , value : Member.Output
                                                    }
                                                    ( \ ( ic
                                                        : { index : Natural
                                                          , value :
                                                              Member.Output
                                                          }
                                                        ) ->
                                                        let colIdx =
                                                              Natural/show
                                                                (ic.index + 1)

                                                        in  if    ic.value.useCodec
                                                            then  if    ic.value.isNullable
                                                                  then      "        String "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Str = rs.getString("
                                                                        ++  colIdx
                                                                        ++  ''
                                                                            );
                                                                            ''
                                                                        ++  "        "
                                                                        ++  ic.value.fieldType
                                                                        ++  " "
                                                                        ++  ic.value.fieldName
                                                                        ++  " = "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Str != null ? "
                                                                        ++  ic.value.codecRef
                                                                        ++  ".decodeInTextFromString("
                                                                        ++  ic.value.fieldName
                                                                        ++  "Str) : null;"
                                                                  else      "        "
                                                                        ++  ic.value.fieldType
                                                                        ++  " "
                                                                        ++  ic.value.fieldName
                                                                        ++  " = "
                                                                        ++  ic.value.codecRef
                                                                        ++  ".decodeInTextFromString(rs.getString("
                                                                        ++  colIdx
                                                                        ++  "));"
                                                            else  if ic.value.isDateType
                                                            then  if    ic.value.isNullable
                                                                  then      "        Date "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Sql = rs.getDate("
                                                                        ++  colIdx
                                                                        ++  ''
                                                                            );
                                                                            ''
                                                                        ++  "        LocalDate "
                                                                        ++  ic.value.fieldName
                                                                        ++  " = "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Sql != null ? "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Sql.toLocalDate() : null;"
                                                                  else      "        LocalDate "
                                                                        ++  ic.value.fieldName
                                                                        ++  " = rs.getDate("
                                                                        ++  colIdx
                                                                        ++  ").toLocalDate();"
                                                            else  if     ic.value.isNullable
                                                                     &&  ic.value.isJdbcPrimitive
                                                            then      "        "
                                                                  ++  ic.value.fieldType
                                                                  ++  " "
                                                                  ++  ic.value.fieldName
                                                                  ++  " = ("
                                                                  ++  ic.value.fieldType
                                                                  ++  ") rs.getObject("
                                                                  ++  colIdx
                                                                  ++  ");"
                                                            else      "        "
                                                                  ++  ic.value.fieldType
                                                                  ++  " "
                                                                  ++  ic.value.fieldName
                                                                  ++  " = rs."
                                                                  ++  ic.value.jdbcGetter
                                                                  ++  "("
                                                                  ++  colIdx
                                                                  ++  ");"
                                                    )
                                                    indexedColumns

                                            in  if    hasCodecDecode
                                                then      ''
                                                                  try {
                                                          ''
                                                      ++  singleDecodeLines
                                                      ++  "\n"
                                                      ++  "            return new Output("
                                                      ++  varRefs
                                                      ++  ''
                                                          );
                                                          ''
                                                      ++  ''
                                                                  } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                                                          ''
                                                      ++  ''
                                                                      throw new IllegalStateException(e);
                                                          ''
                                                      ++  "        }"
                                                else      singleDecodeLines
                                                      ++  "\n"
                                                      ++  "        return new Output("
                                                      ++  varRefs
                                                      ++  ");"
                                          )
                                      ++  "\n"
                                      ++  "    }"
                                  , resultTypeName = typeNameBase ++ ".Output"
                                  }

                            let optionalResult =
                                  { typeDecls = singleResult.typeDecls
                                  , decodeMethod =
                                          ''
                                              @Override
                                          ''
                                      ++  ''
                                              public Output decodeResultSet(ResultSet rs) throws SQLException {
                                          ''
                                      ++  ''
                                                  if (!rs.next()) {
                                          ''
                                      ++  ''
                                                      return null;
                                          ''
                                      ++  ''
                                                  }
                                          ''
                                      ++  ( let optDecodeLines =
                                                  Deps.Prelude.Text.concatMapSep
                                                    "\n"
                                                    { index : Natural
                                                    , value : Member.Output
                                                    }
                                                    ( \ ( ic
                                                        : { index : Natural
                                                          , value :
                                                              Member.Output
                                                          }
                                                        ) ->
                                                        let colIdx =
                                                              Natural/show
                                                                (ic.index + 1)

                                                        in  if    ic.value.useCodec
                                                            then  if    ic.value.isNullable
                                                                  then      "        String "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Str = rs.getString("
                                                                        ++  colIdx
                                                                        ++  ''
                                                                            );
                                                                            ''
                                                                        ++  "        "
                                                                        ++  ic.value.fieldType
                                                                        ++  " "
                                                                        ++  ic.value.fieldName
                                                                        ++  " = "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Str != null ? "
                                                                        ++  ic.value.codecRef
                                                                        ++  ".decodeInTextFromString("
                                                                        ++  ic.value.fieldName
                                                                        ++  "Str) : null;"
                                                                  else      "        "
                                                                        ++  ic.value.fieldType
                                                                        ++  " "
                                                                        ++  ic.value.fieldName
                                                                        ++  " = "
                                                                        ++  ic.value.codecRef
                                                                        ++  ".decodeInTextFromString(rs.getString("
                                                                        ++  colIdx
                                                                        ++  "));"
                                                            else  if ic.value.isDateType
                                                            then  if    ic.value.isNullable
                                                                  then      "        Date "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Sql = rs.getDate("
                                                                        ++  colIdx
                                                                        ++  ''
                                                                            );
                                                                            ''
                                                                        ++  "        LocalDate "
                                                                        ++  ic.value.fieldName
                                                                        ++  " = "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Sql != null ? "
                                                                        ++  ic.value.fieldName
                                                                        ++  "Sql.toLocalDate() : null;"
                                                                  else      "        LocalDate "
                                                                        ++  ic.value.fieldName
                                                                        ++  " = rs.getDate("
                                                                        ++  colIdx
                                                                        ++  ").toLocalDate();"
                                                            else  if     ic.value.isNullable
                                                                     &&  ic.value.isJdbcPrimitive
                                                            then      "        "
                                                                  ++  ic.value.fieldType
                                                                  ++  " "
                                                                  ++  ic.value.fieldName
                                                                  ++  " = ("
                                                                  ++  ic.value.fieldType
                                                                  ++  ") rs.getObject("
                                                                  ++  colIdx
                                                                  ++  ");"
                                                            else      "        "
                                                                  ++  ic.value.fieldType
                                                                  ++  " "
                                                                  ++  ic.value.fieldName
                                                                  ++  " = rs."
                                                                  ++  ic.value.jdbcGetter
                                                                  ++  "("
                                                                  ++  colIdx
                                                                  ++  ");"
                                                    )
                                                    indexedColumns

                                            in  if    hasCodecDecode
                                                then      ''
                                                                  try {
                                                          ''
                                                      ++  optDecodeLines
                                                      ++  "\n"
                                                      ++  "            return new Output("
                                                      ++  varRefs
                                                      ++  ''
                                                          );
                                                          ''
                                                      ++  ''
                                                                  } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                                                          ''
                                                      ++  ''
                                                                      throw new IllegalStateException(e);
                                                          ''
                                                      ++  "        }"
                                                else      optDecodeLines
                                                      ++  "\n"
                                                      ++  "        return new Output("
                                                      ++  varRefs
                                                      ++  ");"
                                          )
                                      ++  "\n"
                                      ++  "    }"
                                  , resultTypeName = typeNameBase ++ ".Output"
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
                                        ''
                                    ++  ''
                                            public String sql() {
                                        ''
                                    ++  "        return \"\"\""
                                    ++  Deps.Lude.Extensions.Text.indent
                                          15
                                          (     "\n"
                                            ++  ctx.sqlExp
                                            ++  ''

                                                """;''
                                          )
                                    ++  "\n"
                                    ++  ''
                                            }
                                        ''
                                    ++  "\n"
                                    ++  ''
                                            @Override
                                        ''
                                    ++  ''
                                            public void bindParams(PreparedStatement ps) throws SQLException {
                                        ''
                                    ++  ctx.paramBindCode
                                    ++  ''
                                            }
                                        ''
                                    ++  "\n"
                                    ++  ''
                                            @Override
                                        ''
                                    ++  ''
                                            public boolean returnsRows() {
                                        ''
                                    ++  ''
                                                return true;
                                        ''
                                    ++  ''
                                            }
                                        ''
                                    ++  "\n"
                                    ++  resolved.decodeMethod
                                    ++  "\n"
                                    ++  "\n"
                                    ++  ''
                                            @Override
                                        ''
                                    ++  "    public "
                                    ++  resolved.resultTypeName
                                    ++  ''
                                         decodeAffectedRows(long affectedRows) {
                                        ''
                                    ++  ''
                                                throw new UnsupportedOperationException();
                                        ''
                                    ++  "    }"
                                , typeDecls = resolved.typeDecls
                                }
                        )
              )
              compiledColumns

in  Algebra.module Input Output run
