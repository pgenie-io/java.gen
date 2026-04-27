let Deps = ../Deps/package.dhall

let Name = Deps.CodegenKit.Name

let reservedKeywords
    : List Name.Type
    = let Char = Deps.Lude.Structures.LatinChar.Type

      let a = Char.A

      let b = Char.B

      let c = Char.C

      let d = Char.D

      let e = Char.E

      let f = Char.F

      let g = Char.G

      let h = Char.H

      let i = Char.I

      let j = Char.J

      let k = Char.K

      let l = Char.L

      let m = Char.M

      let n = Char.N

      let o = Char.O

      let p = Char.P

      let q = Char.Q

      let r = Char.R

      let s = Char.S

      let t = Char.T

      let u = Char.U

      let v = Char.V

      let w = Char.W

      let x = Char.X

      let y = Char.Y

      let z = Char.Z

      let LatinChars/fromList =
            \(charList : List Char) ->
              merge
                { None = { head = z, tail = [] : List Char }
                , Some =
                    \(latinChars : Deps.Lude.Structures.LatinChars.Type) ->
                      latinChars
                }
                (Deps.Lude.Extensions.List.uncons Char charList)

      let Name/fromCharList
          : List Char -> Name.Type
          = \(charList : List Char) ->
              Name.fromLatinChars (LatinChars/fromList charList)

      let charLists =
            [ [ a, b, s, t, r, a, c, t ]
            , [ a, s, s, e, r, t ]
            , [ b, o, o, l, e, a, n ]
            , [ b, r, e, a, k ]
            , [ b, y, t, e ]
            , [ c, a, s, e ]
            , [ c, a, t, c, h ]
            , [ c, h, a, r ]
            , [ c, l, a, s, s ]
            , [ c, o, n, s, t ]
            , [ c, o, n, t, i, n, u, e ]
            , [ d, e, f, a, u, l, t ]
            , [ d, o ]
            , [ d, o, u, b, l, e ]
            , [ e, l, s, e ]
            , [ e, n, u, m ]
            , [ e, x, t, e, n, d, s ]
            , [ f, i, n, a, l ]
            , [ f, i, n, a, l, l, y ]
            , [ f, l, o, a, t ]
            , [ f, o, r ]
            , [ g, o, t, o ]
            , [ i, f ]
            , [ i, m, p, l, e, m, e, n, t, s ]
            , [ i, m, p, o, r, t ]
            , [ i, n, s, t, a, n, c, e, o, f ]
            , [ i, n, t ]
            , [ i, n, t, e, r, f, a, c, e ]
            , [ l, o, n, g ]
            , [ m, o, d, u, l, e ]
            , [ n, a, t, i, v, e ]
            , [ n, e, w ]
            , [ p, a, c, k, a, g, e ]
            , [ p, r, i, v, a, t, e ]
            , [ p, r, o, t, e, c, t, e, d ]
            , [ p, u, b, l, i, c ]
            , [ r, e, c, o, r, d ]
            , [ r, e, t, u, r, n ]
            , [ s, e, a, l, e, d ]
            , [ s, h, o, r, t ]
            , [ s, t, a, t, i, c ]
            , [ s, t, r, i, c, t, f, p ]
            , [ s, u, p, e, r ]
            , [ s, w, i, t, c, h ]
            , [ s, y, n, c, h, r, o, n, i, z, e, d ]
            , [ t, h, i, s ]
            , [ t, h, r, o, w ]
            , [ t, h, r, o, w, s ]
            , [ t, r, a, n, s, i, e, n, t ]
            , [ t, r, y ]
            , [ v, o, i, d ]
            , [ v, o, l, a, t, i, l, e ]
            , [ w, h, i, l, e ]
            , [ e, x, p, o, r, t, s ]
            , [ o, p, e, n ]
            , [ r, e, q, u, i, r, e, s ]
            , [ t, r, a, n, s, i, t, i, v, e ]
            , [ u, s, e, s ]
            , [ p, r, o, v, i, d, e, s ]
            , [ w, i, t, h ]
            , [ v, a, r ]
            , [ r, e, c, o, r, d ]
            , [ y, i, e, l, d ]
            , [ t, r, u, e ]
            , [ f, a, l, s, e ]
            , [ n, u, l, l ]
            ]

      let names =
            Deps.Prelude.List.map
              (List Char)
              Name.Type
              Name/fromCharList
              charLists

      in  names

let isReserved =
      \(name : Name.Type) ->
        Deps.Lude.Extensions.List.elem
          Name.Type
          Name.equality
          name
          reservedKeywords

in  { escape =
        \(name : Name.Type) ->
          let rendered = Name.toTextInCamel name

          in  if isReserved name then "${rendered}_" else rendered
    }
