-- Intended to be executed with:
--
-- ```bash
-- dhall to-directory-tree --file demos/Exhaustive.dhall --output demos/Exhaustive --allow-path-separators
-- ```
--
-- This generates the demo output for the music_catalogue fixture project.
let Sdk = ../src/Deps/Sdk.dhall

let Gen = ../src/package.dhall

let project = Sdk.Fixtures.Exhaustive

in  Sdk.Output.toFileMap
      ( Gen.compile
          ( Some
              { useOptional = True
              , groupId = None Text
              , artifactId = None Text
              , rootPackage = None Text
              }
          )
          project
      )
