-- Intended to be executed with:
--
-- ```bash
-- dhall to-directory-tree --file gen/demo.dhall --output demo-output --allow-path-separators
-- ```
--
-- This generates the demo output for the music_catalogue fixture project.
let Deps = ../gen/Deps/package.dhall

let Gen = ../gen/Gen.dhall

let project = Deps.Sdk.Fixtures.Demo

let compiledFiles = Gen.compileToFileMap (Some { useOptional = True }) project

in  compiledFiles
