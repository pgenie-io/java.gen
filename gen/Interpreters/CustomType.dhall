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
      }

in  Algebra.module
      Input
      Output
      ( \(config : Algebra.Config) ->
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
                                  { moduleName
                                  , typeName
                                  , modulePath
                                  , moduleContent =
                                      Templates.CustomCompositeTypeModule.run
                                        { packageName = config.packageName
                                        , typeName
                                        , pgSchema = input.pgSchema
                                        , pgTypeName = input.pgName
                                        , fields =
                                            Deps.Prelude.List.map
                                              MemberGen.Output
                                              Templates.CustomCompositeTypeModule.Field
                                              ( \(member : MemberGen.Output) ->
                                                  { pgName = member.pgName
                                                  , fieldName = member.fieldName
                                                  , fieldType = member.fieldType
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
                        }
                , Domain =
                    \(value : Model.Value) ->
                      Sdk.Compiled.message
                        Output
                        "Domain types are not yet supported."
                }
                input.definition
      )
