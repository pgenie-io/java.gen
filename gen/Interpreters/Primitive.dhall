let Deps = ../Deps/package.dhall

let Algebra = ../Algebras/Interpreter.dhall

let Input = Deps.Sdk.Project.Primitive

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , imports : Deps.ImportSet.Struct
      , testDefaultLiteral : Text
      }

let noImports = Deps.ImportSet.empty

let codecImports = Deps.ImportSet.codecs

let jsonNodeImports = Deps.ImportSet.jsonNode

let bigDecimalImports = Deps.ImportSet.bigDecimal

let codecBigDecimalImports =
      Deps.ImportSet.combine codecImports bigDecimalImports

let uuidImports = Deps.ImportSet.uuid

let unsupportedType =
      \(type : Text) ->
        Deps.Sdk.Compiled.report Output [ type ] "Unsupported type"

let jdbcPrimitive =
      \(javaType : Text) ->
      \(boxedJavaType : Text) ->
      \(codecName : Text) ->
      \(testDefaultLiteral : Text) ->
        Deps.Sdk.Compiled.ok
          Output
          { javaType
          , boxedJavaType
          , codecRef = "Codec.${codecName}"
          , imports = noImports
          , testDefaultLiteral
          }

let jdbcString =
      \(codecName : Text) ->
        Deps.Sdk.Compiled.ok
          Output
          { javaType = "String"
          , boxedJavaType = "String"
          , codecRef = "Codec.${codecName}"
          , imports = noImports
          , testDefaultLiteral = "\"\""
          }

let dateType =
      Deps.Sdk.Compiled.ok
        Output
        { javaType = "LocalDate"
        , boxedJavaType = "LocalDate"
        , codecRef = "Codec.DATE"
        , imports = noImports
        , testDefaultLiteral = "LocalDate.of(2000, 1, 1)"
        }

let codec =
      \(javaType : Text) ->
      \(codecName : Text) ->
      \(imports : Deps.ImportSet.Struct) ->
        let codecRef = "Codec.${codecName}"

        in  Deps.Sdk.Compiled.ok
              Output
              { javaType
              , boxedJavaType = javaType
              , codecRef
              , imports
              , testDefaultLiteral =
                  "${codecRef}.toAgnostic().random(new java.util.Random(0L), 0)"
              }

let run =
      \(config : Algebra.Config) ->
      \(input : Input) ->
        merge
          { Bit = codec "Bit" "BIT" codecImports
          , Bool = jdbcPrimitive "boolean" "Boolean" "BOOL" "false"
          , Box = codec "Box" "BOX" codecImports
          , Box2D = unsupportedType "box2d"
          , Box3D = unsupportedType "box3d"
          , Bpchar = jdbcString "BPCHAR"
          , Bytea = codec "Bytea" "BYTEA" codecImports
          , Char = codec "Byte" "CHAR" noImports
          , Cidr = codec "Cidr" "CIDR" codecImports
          , Circle = codec "Circle" "CIRCLE" codecImports
          , Citext = codec "String" "CITEXT" noImports
          , Date = dateType
          , Datemultirange =
              codec "Multirange<LocalDate>" "DATEMULTIRANGE" codecImports
          , Daterange = codec "Range<LocalDate>" "DATERANGE" codecImports
          , Float4 = jdbcPrimitive "float" "Float" "FLOAT4" "0.0f"
          , Float8 = jdbcPrimitive "double" "Double" "FLOAT8" "0.0"
          , Geography = unsupportedType "geography"
          , Geometry = unsupportedType "geometry"
          , Hstore = codec "Hstore" "HSTORE" codecImports
          , Inet = codec "Inet" "INET" codecImports
          , Int2 = jdbcPrimitive "short" "Short" "INT2" "(short) 0"
          , Int4 = jdbcPrimitive "int" "Integer" "INT4" "0"
          , Int4multirange =
              codec "Multirange<Integer>" "INT4MULTIRANGE" codecImports
          , Int4range = codec "Range<Integer>" "INT4RANGE" codecImports
          , Int8 = jdbcPrimitive "long" "Long" "INT8" "0L"
          , Int8multirange =
              codec "Multirange<Long>" "INT8MULTIRANGE" codecImports
          , Int8range = codec "Range<Long>" "INT8RANGE" codecImports
          , Interval = codec "Interval" "INTERVAL" codecImports
          , Json = codec "JsonNode" "JSON" jsonNodeImports
          , Jsonb = codec "JsonNode" "JSONB" jsonNodeImports
          , Line = codec "Line" "LINE" codecImports
          , Lseg = codec "Lseg" "LSEG" codecImports
          , Ltree =
              Deps.Sdk.Compiled.ok
                Output
                { javaType = "Ltree"
                , boxedJavaType = "Ltree"
                , codecRef = "Codec.LTREE"
                , imports = codecImports
                , testDefaultLiteral = "new Ltree(List.of(\"root\"))"
                }
          , Macaddr = codec "Macaddr" "MACADDR" codecImports
          , Macaddr8 = codec "Macaddr8" "MACADDR8" codecImports
          , Money = codec "Long" "MONEY" noImports
          , Name = jdbcString "TEXT"
          , Numeric = codec "BigDecimal" "NUMERIC" bigDecimalImports
          , Nummultirange =
              codec
                "Multirange<BigDecimal>"
                "NUMMULTIRANGE"
                codecBigDecimalImports
          , Numrange =
              codec "Range<BigDecimal>" "NUMRANGE" codecBigDecimalImports
          , Oid = codec "Integer" "OID" noImports
          , Path = codec "Path" "PATH" codecImports
          , PgLsn = unsupportedType "pg_lsn"
          , PgSnapshot = unsupportedType "pg_snapshot"
          , Point = codec "Point" "POINT" codecImports
          , Polygon = codec "Polygon" "POLYGON" codecImports
          , Text = jdbcString "TEXT"
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
          , Uuid = codec "UUID" "UUID" uuidImports
          , Varbit = codec "Bit" "VARBIT" codecImports
          , Varchar = jdbcString "VARCHAR"
          , Xml = unsupportedType "xml"
          }
          input

in  Algebra.module Input Output run
