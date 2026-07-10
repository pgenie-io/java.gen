let Sdk = ../Deps/Sdk.dhall

let Lude = ../Deps/Lude.dhall

let Contract = ../Deps/Contract.dhall

let ImportSet = ../Structures/ImportSet.dhall

let ResolvedTarget = ../ResolvedTarget.dhall

let Input = Contract.Primitive

let Output =
      { javaType : Text
      , boxedJavaType : Text
      , codecRef : Text
      , imports : ImportSet.Type
      , testDefaultLiteral : Text
      , testRandomLiteral : Text
      }

let noImports = ImportSet.empty

let codecImports = ImportSet.codecs

let jsonNodeImports = ImportSet.jsonNode

let bigDecimalImports = ImportSet.bigDecimal

let codecBigDecimalImports = ImportSet.combine codecImports bigDecimalImports

let uuidImports = ImportSet.uuid

let unsupportedType =
      \(type : Text) -> Lude.Compiled.report Output [ type ] "Unsupported type"

let jdbcPrimitive =
      \(javaType : Text) ->
      \(boxedJavaType : Text) ->
      \(codecName : Text) ->
      \(testDefaultLiteral : Text) ->
      \(testRandomLiteral : Text) ->
        Lude.Compiled.ok
          Output
          { javaType
          , boxedJavaType
          , codecRef = "Codec.${codecName}"
          , imports = noImports
          , testDefaultLiteral
          , testRandomLiteral
          }

let jdbcString =
      \(codecName : Text) ->
        Lude.Compiled.ok
          Output
          { javaType = "String"
          , boxedJavaType = "String"
          , codecRef = "Codec.${codecName}"
          , imports = noImports
          , testDefaultLiteral = "\"\""
          , testRandomLiteral = "java.util.UUID.randomUUID().toString()"
          }

let dateType =
      Lude.Compiled.ok
        Output
        { javaType = "LocalDate"
        , boxedJavaType = "LocalDate"
        , codecRef = "Codec.DATE"
        , imports = noImports
        , testDefaultLiteral = "LocalDate.of(2000, 1, 1)"
        , testRandomLiteral =
            "Codec.DATE.toAgnostic().random(new java.util.Random(), 0)"
        }

let codec =
      \(javaType : Text) ->
      \(codecName : Text) ->
      \(imports : ImportSet.Type) ->
        let codecRef = "Codec.${codecName}"

        in  Lude.Compiled.ok
              Output
              { javaType
              , boxedJavaType = javaType
              , codecRef
              , imports
              , testDefaultLiteral =
                  "${codecRef}.toAgnostic().random(new java.util.Random(0L), 0)"
              , testRandomLiteral =
                  "${codecRef}.toAgnostic().random(new java.util.Random(), 0)"
              }

let run =
      \(config : ResolvedTarget.Type) ->
      \(input : Input) ->
        merge
          { Bit = codec "Bit" "BIT" codecImports
          , Bool =
              jdbcPrimitive
                "boolean"
                "Boolean"
                "BOOL"
                "false"
                "java.util.concurrent.ThreadLocalRandom.current().nextBoolean()"
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
          , Float4 =
              jdbcPrimitive
                "float"
                "Float"
                "FLOAT4"
                "0.0f"
                "java.util.concurrent.ThreadLocalRandom.current().nextFloat()"
          , Float8 =
              jdbcPrimitive
                "double"
                "Double"
                "FLOAT8"
                "0.0"
                "java.util.concurrent.ThreadLocalRandom.current().nextDouble()"
          , Geography = unsupportedType "geography"
          , Geometry = unsupportedType "geometry"
          , Hstore = codec "Hstore" "HSTORE" codecImports
          , Inet = codec "Inet" "INET" codecImports
          , Int2 =
              jdbcPrimitive
                "short"
                "Short"
                "INT2"
                "(short) 0"
                "(short) java.util.concurrent.ThreadLocalRandom.current().nextInt()"
          , Int4 =
              jdbcPrimitive
                "int"
                "Integer"
                "INT4"
                "0"
                "java.util.concurrent.ThreadLocalRandom.current().nextInt()"
          , Int4multirange =
              codec "Multirange<Integer>" "INT4MULTIRANGE" codecImports
          , Int4range = codec "Range<Integer>" "INT4RANGE" codecImports
          , Int8 =
              jdbcPrimitive
                "long"
                "Long"
                "INT8"
                "0L"
                "java.util.concurrent.ThreadLocalRandom.current().nextLong()"
          , Int8multirange =
              codec "Multirange<Long>" "INT8MULTIRANGE" codecImports
          , Int8range = codec "Range<Long>" "INT8RANGE" codecImports
          , Interval = codec "Interval" "INTERVAL" codecImports
          , Json = codec "JsonNode" "JSON" jsonNodeImports
          , Jsonb = codec "JsonNode" "JSONB" jsonNodeImports
          , Line = codec "Line" "LINE" codecImports
          , Lseg = codec "Lseg" "LSEG" codecImports
          , Ltree =
              Lude.Compiled.ok
                Output
                { javaType = "Ltree"
                , boxedJavaType = "Ltree"
                , codecRef = "Codec.LTREE"
                , imports = codecImports
                , testDefaultLiteral = "new Ltree(List.of(\"root\"))"
                , testRandomLiteral =
                    "new Ltree(List.of(java.util.UUID.randomUUID().toString()))"
                }
          , Macaddr = codec "Macaddr" "MACADDR" codecImports
          , Macaddr8 = codec "Macaddr8" "MACADDR8" codecImports
          , Money = codec "BigDecimal" "money(2)" bigDecimalImports
          , Name = unsupportedType "name"
          , Numeric = codec "BigDecimal" "NUMERIC" bigDecimalImports
          , Nummultirange =
              codec
                "Multirange<BigDecimal>"
                "NUMMULTIRANGE"
                codecBigDecimalImports
          , Numrange =
              codec "Range<BigDecimal>" "NUMRANGE" codecBigDecimalImports
          , Oid = codec "Long" "OID" noImports
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

in  Sdk.Sigs.Interpreter.module ResolvedTarget.Type Input Output run
