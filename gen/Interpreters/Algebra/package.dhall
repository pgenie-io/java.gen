let Deps = ../../Deps/package.dhall

let Config = { rootModuleName : Text, useOptional : Bool }

let module =
      \(Input : Type) ->
      \(Output : Type) ->
        let Result = Deps.Sdk.Compiled.Type Output

        let Run = Config -> Input -> Result

        in  \(run : Run) -> { Input, Output, Result, Run, run }

in  { Config, module }
