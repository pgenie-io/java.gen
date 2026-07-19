-- Intended to be executed with:
--
-- ```bash
-- dhall to-directory-tree --file fixtures/Overridden.dhall --output generated-output/Overridden --allow-path-separators
-- ```
--
-- This generates the demo output for the music_catalogue fixture project with
-- overridden groupId/artifactId, exercising the derive-from-groupId+artifactId
-- root package logic (rootPackage itself is left unset).
let Sdk = ../src/Deps/Sdk.dhall

let Gen = ../src/package.dhall

let project = Sdk.Fixtures.Exhaustive

in  Sdk.Output.toFileMap
      ( Gen.compile
          ( Some
              { useOptional = True
              , groupId = Some "com.example.music"
              , artifactId = Some "catalogue-lib"
              , rootPackage = None Text
              }
          )
          project
      )
