let Self =
      { codecs : Bool
      , jsonNode : Bool
      , bigDecimal : Bool
      , uuid : Bool
      , customTypes : Bool
      }

let empty
    : Self
    = { codecs = False
      , jsonNode = False
      , bigDecimal = False
      , uuid = False
      , customTypes = False
      }

let codecs
    : Self
    = empty // { codecs = True }

let jsonNode
    : Self
    = empty // { jsonNode = True }

let bigDecimal
    : Self
    = empty // { bigDecimal = True }

let uuid
    : Self
    = empty // { uuid = True }

let customTypes
    : Self
    = empty // { customTypes = True }

let combine =
      \(left : Self) ->
      \(right : Self) ->
        { codecs = left.codecs || right.codecs
        , jsonNode = left.jsonNode || right.jsonNode
        , bigDecimal = left.bigDecimal || right.bigDecimal
        , uuid = left.uuid || right.uuid
        , customTypes = left.customTypes || right.customTypes
        }

let importIf =
      \(condition : Bool) ->
      \(import : Text) ->
        if condition then [ import ] else [] : List Text

let toImportLines
    : Self -> Text -> List Text
    = \(self : Self) ->
      \(packageName : Text) ->
          importIf self.codecs "io.codemine.java.postgresql.codecs.*"
        # importIf self.jsonNode "com.fasterxml.jackson.databind.JsonNode"
        # importIf self.bigDecimal "java.math.BigDecimal"
        # importIf self.uuid "java.util.UUID"
        # importIf self.customTypes "${packageName}.types.*"

in  { Type = Self
    , empty
    , codecs
    , jsonNode
    , bigDecimal
    , uuid
    , customTypes
    , combine
    , toImportLines
    }
