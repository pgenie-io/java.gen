let Struct = { codecs : Bool, jsonNode : Bool, bigDecimal : Bool, uuid : Bool }

let empty
    : Struct
    = { codecs = False, jsonNode = False, bigDecimal = False, uuid = False }

let codecs
    : Struct
    = { codecs = True, jsonNode = False, bigDecimal = False, uuid = False }

let jsonNode
    : Struct
    = { codecs = False, jsonNode = True, bigDecimal = False, uuid = False }

let bigDecimal
    : Struct
    = { codecs = False, jsonNode = False, bigDecimal = True, uuid = False }

let uuid
    : Struct
    = { codecs = False, jsonNode = False, bigDecimal = False, uuid = True }

let combine =
      \(left : Struct) ->
      \(right : Struct) ->
        { codecs = left.codecs || right.codecs
        , jsonNode = left.jsonNode || right.jsonNode
        , bigDecimal = left.bigDecimal || right.bigDecimal
        , uuid = left.uuid || right.uuid
        }

in  { Struct, empty, codecs, jsonNode, bigDecimal, uuid, combine }
