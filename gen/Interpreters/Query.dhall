let Deps = ../Deps/package.dhall

let Algebra = ./Algebra/package.dhall

let Lude = Deps.Lude

let Typeclasses = Deps.Typeclasses

let Sdk = Deps.Sdk

let Templates = ../Templates/package.dhall

let ResultModule = ./Result.dhall

let QueryFragmentsModule = ./QueryFragments.dhall

let MemberModule = ./Member.dhall

let Input = Deps.Sdk.Project.Query

let Output =
      { statementModuleName : Text
      , statementModulePath : Text
      , statementModuleContents : Text
      , testModulePath : Text
      , testModuleContents : Text
      }

let mkParamBindCode =
      \(params : List MemberModule.Output) ->
        let indexedParams = Deps.Prelude.List.indexed MemberModule.Output params

        in  Deps.Prelude.Text.concatMap
              { index : Natural, value : MemberModule.Output }
              ( \(ip : { index : Natural, value : MemberModule.Output }) ->
                  let idx = Natural/show (ip.index + 1)

                  in  if    ip.value.useCodec
                      then      "        Jdbc.bind(ps, "
                            ++  idx
                            ++  ", "
                            ++  ip.value.codecRef
                            ++  ", this."
                            ++  ip.value.fieldName
                            ++  ''
                                ());
                                ''
                      else  if ip.value.isDateType
                      then  if    ip.value.isNullable
                            then      "        if (this."
                                  ++  ip.value.fieldName
                                  ++  ''
                                      () != null) {
                                      ''
                                  ++  "            ps.setDate("
                                  ++  idx
                                  ++  ", Date.valueOf(this."
                                  ++  ip.value.fieldName
                                  ++  ''
                                      ()));
                                      ''
                                  ++  ''
                                              } else {
                                      ''
                                  ++  "            ps.setNull("
                                  ++  idx
                                  ++  ''
                                      , Types.DATE);
                                      ''
                                  ++  ''
                                              }
                                      ''
                            else      "        ps.setDate("
                                  ++  idx
                                  ++  ", Date.valueOf(this."
                                  ++  ip.value.fieldName
                                  ++  ''
                                      ()));
                                      ''
                      else  if ip.value.isNullable
                      then      "        if (this."
                            ++  ip.value.fieldName
                            ++  ''
                                () != null) {
                                ''
                            ++  "            ps."
                            ++  ip.value.jdbcSetter
                            ++  "("
                            ++  idx
                            ++  ", this."
                            ++  ip.value.fieldName
                            ++  ''
                                ());
                                ''
                            ++  ''
                                        } else {
                                ''
                            ++  "            ps.setNull("
                            ++  idx
                            ++  ", Types."
                            ++  ip.value.sqlTypesConstant
                            ++  ''
                                );
                                ''
                            ++  ''
                                        }
                                ''
                      else      "        ps."
                            ++  ip.value.jdbcSetter
                            ++  "("
                            ++  idx
                            ++  ", this."
                            ++  ip.value.fieldName
                            ++  ''
                                ());
                                ''
              )
              indexedParams

let render =
      \(config : Algebra.Config) ->
      \(input : Input) ->
      \(result : ResultModule.Output) ->
      \(fragments : QueryFragmentsModule.Output) ->
      \(params : List MemberModule.Output) ->
        let statementModuleName = Deps.CodegenKit.Name.toTextInPascal input.name

        let statementModulePath =
              Deps.CodegenKit.Name.toTextInPascal input.name ++ ".java"

        let paramCastSuffixes =
              Deps.Prelude.List.map
                MemberModule.Output
                Text
                (\(member : MemberModule.Output) -> member.pgCastSuffix)
                params

        let sqlExp = fragments.mkSqlExp paramCastSuffixes

        let paramBindCode = mkParamBindCode params

        let hasResult =
              Deps.Prelude.Optional.fold
                Deps.Sdk.Project.ResultRows
                input.result
                Bool
                (\(_ : Deps.Sdk.Project.ResultRows) -> True)
                False

        let resultInfo = result { sqlExp, paramBindCode } statementModuleName

        let paramFieldList =
              Deps.Prelude.Text.concatMapSep
                ''
                ,
                ''
                MemberModule.Output
                ( \(member : MemberModule.Output) ->
                        ''
                                /**
                        ''
                    ++  "         * Maps to {@code \$"
                    ++  member.pgName
                    ++  "} in the template."
                    ++  (if member.isNullable then " Nullable." else "")
                    ++  "\n"
                    ++  ''
                                 */
                        ''
                    ++  "        "
                    ++  member.fieldType
                    ++  " "
                    ++  member.fieldName
                )
                params

        let resultTypeName =
              if hasResult then statementModuleName ++ ".Output" else "Long"

        let hasCodecParam =
              Deps.Prelude.List.any
                MemberModule.Output
                (\(m : MemberModule.Output) -> m.useCodec)
                params

        let hasDateParam =
              Deps.Prelude.List.any
                MemberModule.Output
                (\(m : MemberModule.Output) -> m.isDateType)
                params

        let hasNullableJdbcParam =
              Deps.Prelude.List.any
                MemberModule.Output
                ( \(m : MemberModule.Output) ->
                    m.isNullable && m.useCodec == False
                )
                params

        let hasCodecResult =
              Deps.Prelude.Optional.fold
                Deps.Sdk.Project.ResultRows
                input.result
                Bool
                (\(rows : Deps.Sdk.Project.ResultRows) -> True)
                False

        let needsArrayListImport =
              Deps.Prelude.Optional.fold
                Deps.Sdk.Project.ResultRows
                input.result
                Bool
                ( \(rows : Deps.Sdk.Project.ResultRows) ->
                    merge
                      { Optional = False, Single = False, Multiple = True }
                      rows.cardinality
                )
                False

        let docComment =
                  ''
                  /**
                  ''
              ++  " * Type-safe binding for the {@code "
              ++  Deps.CodegenKit.Name.toTextInSnake input.name
              ++  ''
                  } query.
                  ''
              ++  ''
                   *
                  ''
              ++  ''
                   * <h2>SQL Template</h2>
                  ''
              ++  ''
                   *
                  ''
              ++  ''
                   * <pre>{@code
                  ''
              ++  " * "
              ++  Deps.Lude.Extensions.Text.prefixEachLine
                    " * "
                    fragments.docComment
              ++  "\n"
              ++  ''
                   * }</pre>
                  ''
              ++  ''
                   *
                  ''
              ++  " * <h2>Source Path</h2> {@code "
              ++  input.srcPath
              ++  ''
                  }
                  ''
              ++  ''
                   *
                  ''
              ++  ''
                   * <p>
                  ''
              ++  ''
                   * Generated from SQL queries using the
                  ''
              ++  ''
                   * <a href="https://pgenie.io">pGenie</a> code generator.
                  ''
              ++  " */"

        let statementModuleContents =
              Templates.StatementModule.run
                { typeName = statementModuleName
                , docComment
                , paramFieldList
                , resultTypeName
                , typeDecls = resultInfo.typeDecls
                , statementImpl = resultInfo.statementImpl
                , hasCodecParam
                , hasDateParam
                , hasNullableJdbcParam
                , needsArrayListImport
                , hasResultType = hasResult
                , hasDateResult = hasResult
                , hasCodecResult = hasResult
                }

        let defaultArgs =
              Deps.Prelude.Text.concatMapSep
                ", "
                MemberModule.Output
                (\(m : MemberModule.Output) -> m.testDefaultLiteral)
                params

        let defaultConstruction = "${statementModuleName}(${defaultArgs})"

        let testModulePath =
              Deps.CodegenKit.Name.toTextInPascal input.name ++ "IT.java"

        let testModuleContents =
              Templates.StatementTestModule.run
                { typeName = statementModuleName
                , defaultConstruction
                , hasResult
                }

        in  { statementModuleName
            , statementModulePath
            , statementModuleContents
            , testModulePath
            , testModuleContents
            }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        Sdk.Compiled.nest
          Output
          input.srcPath
          ( Typeclasses.Classes.Applicative.map3
              Sdk.Compiled.Type
              Sdk.Compiled.applicative
              ResultModule.Output
              QueryFragmentsModule.Output
              (List MemberModule.Output)
              Output
              (render config input)
              ( Sdk.Compiled.nest
                  ResultModule.Output
                  "result"
                  (ResultModule.run config input.result)
              )
              ( Sdk.Compiled.nest
                  QueryFragmentsModule.Output
                  "sql"
                  (QueryFragmentsModule.run config input.fragments)
              )
              ( Sdk.Compiled.nest
                  (List MemberModule.Output)
                  "params"
                  ( Typeclasses.Classes.Applicative.traverseList
                      Sdk.Compiled.Type
                      Sdk.Compiled.applicative
                      Deps.Sdk.Project.Member
                      MemberModule.Output
                      (MemberModule.run config)
                      input.params
                  )
              )
          )

in  Algebra.module Input Output run
