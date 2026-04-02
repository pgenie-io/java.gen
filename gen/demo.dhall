-- Intended to be executed with:
--
-- ```bash
-- dhall to-directory-tree --file gen/demo.dhall --output demo-output --allow-path-separators
-- ```
--
-- This generates the demo output for the music_catalogue fixture project.
let Deps = ./Deps/package.dhall

let Prelude = Deps.Prelude

let Sdk = Deps.Sdk

let Gen = ./Gen.dhall

let project = Sdk.Fixtures._2

let config
    : Gen.Config
    = {=}

let compiledFiles = Gen.compile (None Gen.Config) project

let compiledFileMap =
      Sdk.Compiled.map
        Sdk.Files.Type
        (Prelude.Map.Type Text Text)
        Sdk.Files.toFileMap
        compiledFiles

let fileMap = Sdk.Compiled.toFileMap compiledFileMap

in  fileMap : Prelude.Map.Type Text Text
