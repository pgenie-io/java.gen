let ImportSet = ../Structures/ImportSet.dhall

let ResolvedTarget = ../ResolvedTarget.dhall

let Sdk = ../Deps/Sdk.dhall

let Prelude = ../Deps/Prelude.dhall

let Lude = ../Deps/Lude.dhall

let Model = ../Deps/Contract.dhall

let Templates = ../Templates/package.dhall

let Member = ./Member.dhall

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
      \(config : ResolvedTarget.Type) ->
      \(input : Input) ->
        let typeName = input.name.inPascalCase

        let moduleName = input.name.inPascalCase

        let modulePath = moduleName ++ ".java"

        in  merge
              { Composite =
                  \(members : List Model.Member) ->
                    let compiledMembers
                        : Lude.Compiled.Type (List Member.Output)
                        = Lude.Compiled.traverseList
                            Model.Member
                            Member.Output
                            (Member.run config)
                            members

                    let compiledOutput
                        : Lude.Compiled.Type Output
                        = Lude.Compiled.map
                            (List Member.Output)
                            Output
                            ( \(members : List Member.Output) ->
                                let extraImports =
                                      List/fold
                                        Member.Output
                                        members
                                        ImportSet.Type
                                        ( \(member : Member.Output) ->
                                          \(acc : ImportSet.Type) ->
                                            ImportSet.combine member.imports acc
                                        )
                                        ImportSet.empty

                                let moduleImports =
                                      extraImports // { customTypes = False }

                                let Combination = List Text

                                let FieldSpec =
                                      { testPresentLiteral : Text
                                      , testAbsentLiteral : Text
                                      , isVariable : Bool
                                      }

                                let fieldSpecs
                                    : List FieldSpec
                                    = Prelude.List.map
                                        Member.Output
                                        FieldSpec
                                        ( \(m : Member.Output) ->
                                            { testPresentLiteral =
                                                m.testPresentLiteral
                                            , testAbsentLiteral =
                                                m.testAbsentLiteral
                                            , isVariable = m.isNullable
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
                                            then  Prelude.List.concatMap
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
                                            else  Prelude.List.map
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
                                      Prelude.List.map
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
                                                Prelude.Text.concatSep
                                                  ", "
                                                  indexed.value
                                            }
                                        )
                                        ( Prelude.List.indexed
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
                                          , extraImports = moduleImports
                                          , fields =
                                              Prelude.List.map
                                                Member.Output
                                                Templates.CustomCompositeTypeModule.Field
                                                ( \(member : Member.Output) ->
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
                                                    , isOptional =
                                                        member.isOptional
                                                    }
                                                )
                                                members
                                          , useOptional = config.useOptional
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
                                          , useOptional = config.useOptional
                                          }
                                    }
                            )
                            compiledMembers

                    in  compiledOutput
              , Enum =
                  \(variants : List Model.EnumVariant) ->
                    Lude.Compiled.ok
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
                                Prelude.List.map
                                  Model.EnumVariant
                                  Templates.CustomEnumTypeModule.Variant
                                  ( \(variant : Model.EnumVariant) ->
                                      { name = variant.name.inPascalCase
                                      , pgValue = variant.pgName
                                      }
                                  )
                                  variants
                            , useOptional = config.useOptional
                            }
                      , testModuleName = moduleName ++ "IT"
                      , testModulePath = moduleName ++ "IT.java"
                      , testModuleContent =
                          Templates.CustomEnumTypeTestModule.run
                            { packageName = config.packageName
                            , typeName
                            , pgTypeName = input.pgName
                            , variants =
                                Prelude.List.map
                                  Model.EnumVariant
                                  Templates.CustomEnumTypeTestModule.Variant
                                  ( \(variant : Model.EnumVariant) ->
                                      { variantName = variant.name.inPascalCase
                                      }
                                  )
                                  variants
                            , useOptional = config.useOptional
                            }
                      }
              , Domain =
                  \(_ : Model.Value) ->
                    Lude.Compiled.message
                      Output
                      "Domain types are not yet supported."
              }
              input.definition

in  Sdk.Sigs.Interpreter.module ResolvedTarget.Type Input Output run
