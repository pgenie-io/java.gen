let Self = { codecs : Bool, jsonNode : Bool, bigDecimal : Bool, uuid : Bool }

let empty
    : Self
    = { codecs = False, jsonNode = False, bigDecimal = False, uuid = False }

let codecs
    : Self
    = { codecs = True, jsonNode = False, bigDecimal = False, uuid = False }

let jsonNode
    : Self
    = { codecs = False, jsonNode = True, bigDecimal = False, uuid = False }

let bigDecimal
    : Self
    = { codecs = False, jsonNode = False, bigDecimal = True, uuid = False }

let uuid
    : Self
    = { codecs = False, jsonNode = False, bigDecimal = False, uuid = True }

let combine =
      \(left : Self) ->
      \(right : Self) ->
        { codecs = left.codecs || right.codecs
        , jsonNode = left.jsonNode || right.jsonNode
        , bigDecimal = left.bigDecimal || right.bigDecimal
        , uuid = left.uuid || right.uuid
        }

in  { Type = Self, empty, codecs, jsonNode, bigDecimal, uuid, combine }
