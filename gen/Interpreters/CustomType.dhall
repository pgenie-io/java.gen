let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Sdk = Deps.Sdk

let Model = Deps.Sdk.Project

let Templates = ../Templates/package.dhall

let MemberGen = ./CustomTypeMember.dhall

let Input = Model.CustomType

let Output =
      { moduleName : Text
      , typeName : Text
      , modulePath : Text
      , moduleContent : Text
      , testModuleName : Text
      , testModulePath : Text
      , testModuleContent : Text
      }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        let typeName = Deps.CodegenKit.Name.toTextInPascal input.name

        let moduleName = Deps.CodegenKit.Name.toTextInPascal input.name

        let modulePath = moduleName ++ ".java"

        in  merge
              { Composite =
                  \(members : List Model.Member) ->
                    let compiledMembers
                        : Sdk.Compiled.Type (List MemberGen.Output)
                        = Sdk.Compiled.traverseList
                            Model.Member
                            MemberGen.Output
                            (MemberGen.run config)
                            members

                    let compiledOutput
                        : Sdk.Compiled.Type Output
                        = Sdk.Compiled.map
                            (List MemberGen.Output)
                            Output
                            ( \(members : List MemberGen.Output) ->
                                let extraImports =
                                      List/fold
                                        MemberGen.Output
                                        members
                                        Deps.ImportSet.Struct
                                        ( \(member : MemberGen.Output) ->
                                          \(acc : Deps.ImportSet.Struct) ->
                                            Deps.ImportSet.combine
                                              member.imports
                                              acc
                                        )
                                        Deps.ImportSet.empty

                                let Combination = List Text

                                let FieldSpec =
                                      { testPresentLiteral : Text
                                      , testAbsentLiteral : Text
                                      , isVariable : Bool
                                      }

                                let fieldSpecs
                                    : List FieldSpec
                                    = Deps.Prelude.List.map
                                        MemberGen.Output
                                        FieldSpec
                                        ( \(m : MemberGen.Output) ->
                                            { testPresentLiteral =
                                                m.testPresentLiteral
                                            , testAbsentLiteral =
                                                m.testAbsentLiteral
                                            , isVariable =
                                                    m.isNullable
                                                &&  Deps.Prelude.Bool.not
                                                      m.testLiteralIsNull
                                            }
                                        )
                                        members

                                let combinations
                                    : List Combination
                                    = List/fold
                                        FieldSpec
                                        fieldSpecs
                                        (List Combination)
                                        ( \(spec : FieldSpec) ->
                                          \(combos : List Combination) ->
                                            if    spec.isVariable
                                            then  Deps.Prelude.List.concatMap
                                                    Combination
                                                    Combination
                                                    ( \(combo : Combination) ->
                                                        [   [ spec.testAbsentLiteral
                                                            ]
                                                          # combo
                                                        ,   [ spec.testPresentLiteral
                                                            ]
                                                          # combo
                                                        ]
                                                    )
                                                    combos
                                            else  Deps.Prelude.List.map
                                                    Combination
                                                    Combination
                                                    ( \(combo : Combination) ->
                                                          [ spec.testPresentLiteral
                                                          ]
                                                        # combo
                                                    )
                                                    combos
                                        )
                                        [ [] : Combination ]

                                let testCases =
                                      Deps.Prelude.List.map
                                        { index : Natural, value : Combination }
                                        Templates.CustomCompositeTypeTestModule.TestCase
                                        ( \ ( indexed
                                            : { index : Natural
                                              , value : Combination
                                              }
                                            ) ->
                                            { testName =
                                                "roundtripCombination${Natural/show
                                                                         indexed.index}"
                                            , constructorArgs =
                                                Deps.Prelude.Text.concatSep
                                                  ", "
                                                  indexed.value
                                            }
                                        )
                                        ( Deps.Prelude.List.indexed
                                            Combination
                                            combinations
                                        )

                                in  { moduleName
                                    , typeName
                                    , modulePath
                                    , moduleContent =
                                        Templates.CustomCompositeTypeModule.run
                                          { packageName = config.packageName
                                          , typeName
                                          , pgSchema = input.pgSchema
                                          , pgTypeName = input.pgName
                                          , extraImports
                                          , fields =
                                              Deps.Prelude.List.map
                                                MemberGen.Output
                                                Templates.CustomCompositeTypeModule.Field
                                                ( \ ( member
                                                    : MemberGen.Output
                                                    ) ->
                                                    { pgName = member.pgName
                                                    , fieldName =
                                                        member.fieldName
                                                    , fieldType =
                                                        member.fieldType
                                                    , rawCodecType =
                                                        member.rawCodecType
                                                    , elementIsOptional =
                                                        member.elementIsOptional
                                                    , codecRef = member.codecRef
                                                    , isDateType =
                                                        member.isDateType
                                                    , isOptional =
                                                        member.isOptional
                                                    }
                                                )
                                                members
                                          }
                                    , testModuleName = moduleName ++ "IT"
                                    , testModulePath = moduleName ++ "IT.java"
                                    , testModuleContent =
                                        Templates.CustomCompositeTypeTestModule.run
                                          { packageName = config.packageName
                                          , typeName
                                          , pgTypeName = input.pgName
                                          , needsCodecsImport =
                                              extraImports.codecs
                                          , testCases
                                          }
                                    }
                            )
                            compiledMembers

                    in  compiledOutput
              , Enum =
                  \(variants : List Model.EnumVariant) ->
                    Sdk.Compiled.ok
                      Output
                      { moduleName
                      , typeName
                      , modulePath
                      , moduleContent =
                          Templates.CustomEnumTypeModule.run
                            { packageName = config.packageName
                            , typeName
                            , pgSchema = input.pgSchema
                            , pgTypeName = input.pgName
                            , variants =
                                Deps.Prelude.List.map
                                  Model.EnumVariant
                                  Templates.CustomEnumTypeModule.Variant
                                  ( \(variant : Model.EnumVariant) ->
                                      { name =
                                          Deps.CodegenKit.Name.toTextInPascal
                                            variant.name
                                      , pgValue = variant.pgName
                                      }
                                  )
                                  variants
                            }
                      , testModuleName = moduleName ++ "IT"
                      , testModulePath = moduleName ++ "IT.java"
                      , testModuleContent =
                          Templates.CustomEnumTypeTestModule.run
                            { packageName = config.packageName
                            , typeName
                            , pgTypeName = input.pgName
                            , variants =
                                Deps.Prelude.List.map
                                  Model.EnumVariant
                                  Templates.CustomEnumTypeTestModule.Variant
                                  ( \(variant : Model.EnumVariant) ->
                                      { variantName =
                                          Deps.CodegenKit.Name.toTextInPascal
                                            variant.name
                                      }
                                  )
                                  variants
                            }
                      }
              , Domain =
                  \(_ : Model.Value) ->
                    Sdk.Compiled.message
                      Output
                      "Domain types are not yet supported."
              }
              input.definition

in  Algebra.module Input Output run
