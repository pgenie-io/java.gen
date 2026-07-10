-- Intended to be executed with:
--
-- ```bash
-- dhall to-directory-tree --file tests/Exhaustive.dhall --output demo-output --allow-path-separators
-- ```
--
-- This generates the demo output for the music_catalogue fixture project.
let Deps = ../gen/Deps/package.dhall

let Gen = ../gen/Gen.dhall

let project = Deps.Sdk.Fixtures.Exhaustive

in  Deps.Sdk.Output.toFileMap
      (Gen.compile (Some { useOptional = True }) project)
