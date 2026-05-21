let Deps = ./Deps/package.dhall

let Sdk = Deps.Sdk

in  Sdk.module { major = 2, minor = 0 } ./Config.dhall ./compile.dhall
