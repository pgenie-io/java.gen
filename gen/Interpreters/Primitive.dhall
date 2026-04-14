let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Input = Deps.Sdk.Project.Primitive

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , imports : List Text
      , isDateType : Bool
      , jdbcSetter : Text
      , sqlTypesConstant : Text
      , testDefaultLiteral : Text
      }

let noImports
    : List Text
    = [] : List Text

let codecImports = [ "io.codemine.java.postgresql.codecs.*" ]

let unsupportedType =
      \(type : Text) ->
        Deps.Sdk.Compiled.report Output [ type ] "Unsupported type"

let jdbcPrimitive =
      \(javaType : Text) ->
      \(boxedJavaType : Text) ->
      \(codecName : Text) ->
      \(jdbcSetter : Text) ->
      \(sqlTypesConstant : Text) ->
      \(testDefaultLiteral : Text) ->
        Deps.Sdk.Compiled.ok
          Output
          { javaType
          , boxedJavaType
          , codecRef = "Codec.${codecName}"
          , imports = noImports
          , isDateType = False
          , jdbcSetter
          , sqlTypesConstant
          , testDefaultLiteral
          }

let jdbcString =
      \(codecName : Text) ->
      \(sqlTypesConstant : Text) ->
        Deps.Sdk.Compiled.ok
          Output
          { javaType = "String"
          , boxedJavaType = "String"
          , codecRef = "Codec.${codecName}"
          , imports = noImports
          , isDateType = False
          , jdbcSetter = "setString"
          , sqlTypesConstant
          , testDefaultLiteral = "\"\""
          }

let dateType =
      Deps.Sdk.Compiled.ok
        Output
        { javaType = "LocalDate"
        , boxedJavaType = "LocalDate"
        , codecRef = "Codec.DATE"
        , imports = noImports
        , isDateType = True
        , jdbcSetter = ""
        , sqlTypesConstant = "DATE"
        , testDefaultLiteral = "LocalDate.of(2000, 1, 1)"
        }

let codec =
      \(javaType : Text) ->
      \(codecName : Text) ->
      \(imports : List Text) ->
        Deps.Sdk.Compiled.ok
          Output
          { javaType
          , boxedJavaType = javaType
          , codecRef = "Codec.${codecName}"
          , imports
          , isDateType = False
          , jdbcSetter = ""
          , sqlTypesConstant = ""
          , testDefaultLiteral = "null"
          }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        merge
          { Bit = codec "Bit" "BIT" codecImports
          , Bool =
              jdbcPrimitive
                "boolean"
                "Boolean"
                "BOOL"
                "setBoolean"
                "BOOLEAN"
                "false"
          , Box = codec "Box" "BOX" codecImports
          , Box2D = unsupportedType "box2d"
          , Box3D = unsupportedType "box3d"
          , Bpchar = jdbcString "BPCHAR" "CHAR"
          , Bytea = codec "Bytea" "BYTEA" codecImports
          , Char = codec "Byte" "CHAR" noImports
          , Cidr = codec "Cidr" "CIDR" codecImports
          , Circle = codec "Circle" "CIRCLE" codecImports
          , Citext = codec "String" "CITEXT" noImports
          , Date = dateType
          , Datemultirange =
              codec "Multirange<LocalDate>" "DATEMULTIRANGE" codecImports
          , Daterange = codec "Range<LocalDate>" "DATERANGE" codecImports
          , Float4 =
              jdbcPrimitive "float" "Float" "FLOAT4" "setFloat" "REAL" "0.0f"
          , Float8 =
              jdbcPrimitive
                "double"
                "Double"
                "FLOAT8"
                "setDouble"
                "DOUBLE"
                "0.0"
          , Geography = unsupportedType "geography"
          , Geometry = unsupportedType "geometry"
          , Hstore = codec "Hstore" "HSTORE" codecImports
          , Inet = codec "Inet" "INET" codecImports
          , Int2 =
              jdbcPrimitive
                "short"
                "Short"
                "INT2"
                "setShort"
                "SMALLINT"
                "(short) 0"
          , Int4 = jdbcPrimitive "int" "Integer" "INT4" "setInt" "INTEGER" "0"
          , Int4multirange =
              codec "Multirange<Integer>" "INT4MULTIRANGE" codecImports
          , Int4range = codec "Range<Integer>" "INT4RANGE" codecImports
          , Int8 = jdbcPrimitive "long" "Long" "INT8" "setLong" "BIGINT" "0L"
          , Int8multirange =
              codec "Multirange<Long>" "INT8MULTIRANGE" codecImports
          , Int8range = codec "Range<Long>" "INT8RANGE" codecImports
          , Interval = codec "Interval" "INTERVAL" codecImports
          , Json =
              codec
                "JsonNode"
                "JSON"
                [ "com.fasterxml.jackson.databind.JsonNode" ]
          , Jsonb =
              codec
                "JsonNode"
                "JSONB"
                [ "com.fasterxml.jackson.databind.JsonNode" ]
          , Line = codec "Line" "LINE" codecImports
          , Lseg = codec "Lseg" "LSEG" codecImports
          , Ltree = codec "Ltree" "LTREE" codecImports
          , Macaddr = codec "Macaddr" "MACADDR" codecImports
          , Macaddr8 = codec "Macaddr8" "MACADDR8" codecImports
          , Money = codec "Long" "MONEY" noImports
          , Name = jdbcString "TEXT" "VARCHAR"
          , Numeric = codec "BigDecimal" "NUMERIC" [ "java.math.BigDecimal" ]
          , Nummultirange =
              codec
                "Multirange<BigDecimal>"
                "NUMMULTIRANGE"
                (codecImports # [ "java.math.BigDecimal" ])
          , Numrange =
              codec
                "Range<BigDecimal>"
                "NUMRANGE"
                (codecImports # [ "java.math.BigDecimal" ])
          , Oid = codec "Integer" "OID" noImports
          , Path = codec "Path" "PATH" codecImports
          , PgLsn = unsupportedType "pg_lsn"
          , PgSnapshot = unsupportedType "pg_snapshot"
          , Point = codec "Point" "POINT" codecImports
          , Polygon = codec "Polygon" "POLYGON" codecImports
          , Text = jdbcString "TEXT" "VARCHAR"
          , Time = codec "LocalTime" "TIME" noImports
          , Timestamp = codec "LocalDateTime" "TIMESTAMP" noImports
          , Timestamptz = codec "Instant" "TIMESTAMPTZ" noImports
          , Timetz = codec "Timetz" "TIMETZ" codecImports
          , Tsmultirange =
              codec "Multirange<LocalDateTime>" "TSMULTIRANGE" codecImports
          , Tsquery = unsupportedType "tsquery"
          , Tsrange = codec "Range<LocalDateTime>" "TSRANGE" codecImports
          , Tstzmultirange =
              codec "Multirange<Instant>" "TSTZMULTIRANGE" codecImports
          , Tstzrange = codec "Range<Instant>" "TSTZRANGE" codecImports
          , Tsvector = codec "Tsvector" "TSVECTOR" codecImports
          , Uuid = codec "UUID" "UUID" [ "java.util.UUID" ]
          , Varbit = codec "Bit" "VARBIT" codecImports
          , Varchar = jdbcString "VARCHAR" "VARCHAR"
          , Xml = unsupportedType "xml"
          }
          input

in  Algebra.module Input Output run
