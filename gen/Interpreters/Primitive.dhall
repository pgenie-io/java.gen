let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Input = Deps.Sdk.Project.Primitive

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , useCodec : Bool
      , isDateType : Bool
      , isJdbcPrimitive : Bool
      , jdbcSetter : Text
      , jdbcGetter : Text
      , sqlTypesConstant : Text
      , pgCastSuffix : Text
      , testDefaultLiteral : Text
      }

let unsupportedType =
      \(type : Text) ->
        Deps.Sdk.Compiled.report Output [ type ] "Unsupported type"

let jdbcPrimitive =
      \(javaType : Text) ->
      \(boxedJavaType : Text) ->
      \(codecName : Text) ->
      \(jdbcSetter : Text) ->
      \(jdbcGetter : Text) ->
      \(sqlTypesConstant : Text) ->
      \(testDefaultLiteral : Text) ->
        Deps.Sdk.Compiled.ok
          Output
          { javaType
          , boxedJavaType
          , codecRef = "Codec.${codecName}"
          , useCodec = False
          , isDateType = False
          , isJdbcPrimitive = True
          , jdbcSetter
          , jdbcGetter
          , sqlTypesConstant
          , pgCastSuffix = ""
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
          , useCodec = False
          , isDateType = False
          , isJdbcPrimitive = False
          , jdbcSetter = "setString"
          , jdbcGetter = "getString"
          , sqlTypesConstant
          , pgCastSuffix = ""
          , testDefaultLiteral = "\"\""
          }

let dateType =
      Deps.Sdk.Compiled.ok
        Output
        { javaType = "LocalDate"
        , boxedJavaType = "LocalDate"
        , codecRef = "Codec.DATE"
        , useCodec = False
        , isDateType = True
        , isJdbcPrimitive = False
        , jdbcSetter = ""
        , jdbcGetter = ""
        , sqlTypesConstant = "DATE"
        , pgCastSuffix = ""
        , testDefaultLiteral = "LocalDate.of(2000, 1, 1)"
        }

let codec =
      \(javaType : Text) ->
      \(codecName : Text) ->
        Deps.Sdk.Compiled.ok
          Output
          { javaType
          , boxedJavaType = javaType
          , codecRef = "Codec.${codecName}"
          , useCodec = True
          , isDateType = False
          , isJdbcPrimitive = False
          , jdbcSetter = ""
          , jdbcGetter = ""
          , sqlTypesConstant = ""
          , pgCastSuffix = ""
          , testDefaultLiteral = "null"
          }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        merge
          { Bit = codec "Bit" "BIT"
          , Bool =
              jdbcPrimitive
                "boolean"
                "Boolean"
                "BOOL"
                "setBoolean"
                "getBoolean"
                "BOOLEAN"
                "false"
          , Box = codec "Box" "BOX"
          , Bpchar = jdbcString "BPCHAR" "CHAR"
          , Bytea = codec "Bytea" "BYTEA"
          , Char = codec "Byte" "CHAR"
          , Cidr = codec "Cidr" "CIDR"
          , Circle = codec "Circle" "CIRCLE"
          , Citext = codec "String" "CITEXT"
          , Date = dateType
          , Datemultirange = codec "Multirange<LocalDate>" "DATEMULTIRANGE"
          , Daterange = codec "Range<LocalDate>" "DATERANGE"
          , Float4 =
              jdbcPrimitive
                "float"
                "Float"
                "FLOAT4"
                "setFloat"
                "getFloat"
                "REAL"
                "0.0f"
          , Float8 =
              jdbcPrimitive
                "double"
                "Double"
                "FLOAT8"
                "setDouble"
                "getDouble"
                "DOUBLE"
                "0.0"
          , Hstore = codec "Hstore" "HSTORE"
          , Inet = codec "Inet" "INET"
          , Int2 =
              jdbcPrimitive
                "short"
                "Short"
                "INT2"
                "setShort"
                "getShort"
                "SMALLINT"
                "(short) 0"
          , Int4 =
              jdbcPrimitive
                "int"
                "Integer"
                "INT4"
                "setInt"
                "getInt"
                "INTEGER"
                "0"
          , Int4multirange = codec "Multirange<Integer>" "INT4MULTIRANGE"
          , Int4range = codec "Range<Integer>" "INT4RANGE"
          , Int8 =
              jdbcPrimitive
                "long"
                "Long"
                "INT8"
                "setLong"
                "getLong"
                "BIGINT"
                "0L"
          , Int8multirange = codec "Multirange<Long>" "INT8MULTIRANGE"
          , Int8range = codec "Range<Long>" "INT8RANGE"
          , Interval = codec "Interval" "INTERVAL"
          , Json = codec "JsonNode" "JSON"
          , Jsonb = codec "JsonNode" "JSONB"
          , Line = codec "Line" "LINE"
          , Lseg = codec "Lseg" "LSEG"
          , Macaddr = codec "Macaddr" "MACADDR"
          , Macaddr8 = codec "Macaddr8" "MACADDR8"
          , Money = codec "Long" "MONEY"
          , Name = jdbcString "TEXT" "VARCHAR"
          , Numeric = codec "BigDecimal" "NUMERIC"
          , Nummultirange = codec "Multirange<BigDecimal>" "NUMMULTIRANGE"
          , Numrange = codec "Range<BigDecimal>" "NUMRANGE"
          , Oid = codec "Integer" "OID"
          , Path = codec "Path" "PATH"
          , PgLsn = unsupportedType "pg_lsn"
          , PgSnapshot = unsupportedType "pg_snapshot"
          , Point = codec "Point" "POINT"
          , Polygon = codec "Polygon" "POLYGON"
          , Text = jdbcString "TEXT" "VARCHAR"
          , Time = codec "LocalTime" "TIME"
          , Timestamp = codec "LocalDateTime" "TIMESTAMP"
          , Timestamptz = codec "Instant" "TIMESTAMPTZ"
          , Timetz = codec "Timetz" "TIMETZ"
          , Tsmultirange = codec "Multirange<LocalDateTime>" "TSMULTIRANGE"
          , Tsquery = unsupportedType "tsquery"
          , Tsrange = codec "Range<LocalDateTime>" "TSRANGE"
          , Tstzmultirange = codec "Multirange<Instant>" "TSTZMULTIRANGE"
          , Tstzrange = codec "Range<Instant>" "TSTZRANGE"
          , Tsvector = codec "Tsvector" "TSVECTOR"
          , Uuid = codec "UUID" "UUID"
          , Varbit = codec "Bit" "VARBIT"
          , Varchar = jdbcString "VARCHAR" "VARCHAR"
          , Xml = unsupportedType "xml"
          }
          input

in  Algebra.module Input Output run
