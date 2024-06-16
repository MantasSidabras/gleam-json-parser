# JSON parser

A functional json parser written using monadic parser combinators

Currently it does not support exponential numbers and string escape characters

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
