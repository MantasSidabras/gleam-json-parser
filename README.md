# JSON parser

A functional json parser written using monadic parser combinators

Currently it does not support exponential numbers and string escape characters

## Gleam JSON type

Json is parsed using the following JsonValue type

```gleam
pub type JsonValue {
  JsonNull
  JsonBool(Bool)
  JsonNumber(Float)
  JsonString(String)
  JsonArray(List(JsonValue))
  JsonObject(List(#(String, JsonValue)))
}
```


## Example

Parses this json

```json
{
  "age": 12.123,
  "name": "Eric Cartman",
  "favourite color": "red",
  "cars": [
    "toyota prius 2004",
    "Hot dog",
    {
      "x": false
    }
  ]
}
```

into this gleam expression

```gleam
#([], JsonObject([#("age", JsonNumber(12.123)), #("name", JsonString("Eric Cartman")), #("favourite color", JsonString("red")), #("cars", JsonArray([JsonString("toyota prius 2004"), JsonString("Hot dog"), JsonObject([#("x", JsonBool(False))])]))]))
```
