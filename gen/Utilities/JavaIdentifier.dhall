let Deps = ../Deps/package.dhall

let Name = Deps.CodegenKit.Name

let L = Name.Head.Char.Type

let mk =
      \(head : Name.Head.Char.Type) ->
      \(tail : List Name.Head.Char.Type) ->
        Name.word head tail

let reservedKeywords
    : List Name.Type
    = [ mk L.A [ L.B, L.S, L.T, L.R, L.A, L.C, L.T ]
      , mk L.A [ L.S, L.S, L.E, L.R, L.T ]
      , mk L.B [ L.O, L.O, L.L, L.E, L.A, L.N ]
      , mk L.B [ L.R, L.E, L.A, L.K ]
      , mk L.B [ L.Y, L.T, L.E ]
      , mk L.C [ L.A, L.S, L.E ]
      , mk L.C [ L.A, L.T, L.C, L.H ]
      , mk L.C [ L.H, L.A, L.R ]
      , mk L.C [ L.L, L.A, L.S, L.S ]
      , mk L.C [ L.O, L.N, L.S, L.T ]
      , mk L.C [ L.O, L.N, L.T, L.I, L.N, L.U, L.E ]
      , mk L.D [ L.E, L.F, L.A, L.U, L.L, L.T ]
      , mk L.D [ L.O ]
      , mk L.D [ L.O, L.U, L.B, L.L, L.E ]
      , mk L.E [ L.L, L.S, L.E ]
      , mk L.E [ L.N, L.U, L.M ]
      , mk L.E [ L.X, L.T, L.E, L.N, L.D, L.S ]
      , mk L.F [ L.I, L.N, L.A, L.L ]
      , mk L.F [ L.I, L.N, L.A, L.L, L.L, L.Y ]
      , mk L.F [ L.L, L.O, L.A, L.T ]
      , mk L.F [ L.O, L.R ]
      , mk L.G [ L.O, L.T, L.O ]
      , mk L.I [ L.F ]
      , mk L.I [ L.M, L.P, L.L, L.E, L.M, L.E, L.N, L.T, L.S ]
      , mk L.I [ L.M, L.P, L.O, L.R, L.T ]
      , mk L.I [ L.N, L.S, L.T, L.A, L.N, L.C, L.E, L.O, L.F ]
      , mk L.I [ L.N, L.T ]
      , mk L.I [ L.N, L.T, L.E, L.R, L.F, L.A, L.C, L.E ]
      , mk L.L [ L.O, L.N, L.G ]
      , mk L.M [ L.O, L.D, L.U, L.L, L.E ]
      , mk L.N [ L.A, L.T, L.I, L.V, L.E ]
      , mk L.N [ L.E, L.W ]
      , mk L.P [ L.A, L.C, L.K, L.A, L.G, L.E ]
      , mk L.P [ L.R, L.I, L.V, L.A, L.T, L.E ]
      , mk L.P [ L.R, L.O, L.T, L.E, L.C, L.T, L.E, L.D ]
      , mk L.P [ L.U, L.B, L.L, L.I, L.C ]
      , mk L.R [ L.E, L.C, L.O, L.R, L.D ]
      , mk L.R [ L.E, L.T, L.U, L.R, L.N ]
      , mk L.S [ L.E, L.A, L.L, L.E, L.D ]
      , mk L.S [ L.H, L.O, L.R, L.T ]
      , mk L.S [ L.T, L.A, L.T, L.I, L.C ]
      , mk L.S [ L.T, L.R, L.I, L.C, L.T, L.F, L.P ]
      , mk L.S [ L.U, L.P, L.E, L.R ]
      , mk L.S [ L.W, L.I, L.T, L.C, L.H ]
      , mk L.S [ L.Y, L.N, L.C, L.H, L.R, L.O, L.N, L.I, L.Z, L.E, L.D ]
      , mk L.T [ L.H, L.I, L.S ]
      , mk L.T [ L.H, L.R, L.O, L.W ]
      , mk L.T [ L.H, L.R, L.O, L.W, L.S ]
      , mk L.T [ L.R, L.A, L.N, L.S, L.I, L.E, L.N, L.T ]
      , mk L.T [ L.R, L.Y ]
      , mk L.V [ L.O, L.I, L.D ]
      , mk L.V [ L.O, L.L, L.A, L.T, L.I, L.L, L.E ]
      , mk L.W [ L.H, L.I, L.L, L.E ]
      , mk L.E [ L.X, L.P, L.O, L.R, L.T, L.S ]
      , mk L.O [ L.P, L.E, L.N ]
      , mk L.R [ L.E, L.Q, L.U, L.I, L.R, L.E, L.S ]
      , mk L.T [ L.R, L.A, L.N, L.S, L.I, L.T, L.I, L.V, L.E ]
      , mk L.U [ L.S, L.E, L.S ]
      , mk L.P [ L.R, L.O, L.V, L.I, L.D, L.E, L.S ]
      , mk L.W [ L.I, L.T, L.H ]
      , mk L.V [ L.A, L.R ]
      , mk L.R [ L.E, L.C, L.O, L.R, L.D ]
      , mk L.Y [ L.I, L.E, L.L, L.D ]
      , mk L.T [ L.R, L.U, L.E ]
      , mk L.F [ L.A, L.L, L.S, L.E ]
      , mk L.N [ L.U, L.L, L.L ]
      ]

let isReserved =
      \(name : Name.Type) ->
        Deps.Prelude.List.any
          Name.Type
          (\(keyword : Name.Type) -> Name.equality.equal name keyword)
          reservedKeywords

in  { escape =
        \(name : Name.Type) ->
          let rendered = Name.toTextInCamel name

          in  if isReserved name then "${rendered}_" else rendered
    }
