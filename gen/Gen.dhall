let Deps = ./Deps/package.dhall

let Sdk = Deps.Sdk

in  Sdk.module ./Config.dhall ./compile.dhall
