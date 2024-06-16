import char.{
  type Char, type Str, char, char_to_string, str, str_to_int, str_to_string,
}
import gleam/float
import gleam/function.{curry2}
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import parser.{
  type Parser, Parser, bind, drop_left, drop_right, empty, fmap, many, or, pure,
  return, sequence_a, some, span_p,
}

pub type JsonValue {
  JsonNull
  JsonBool(Bool)
  JsonNumber(Float)
  JsonString(String)
  JsonArray(List(JsonValue))
  JsonObject(List(#(String, JsonValue)))
}

type ParseError =
  String

type ParseResult(a) =
  Result(#(Str, a), ParseError)

fn print_parse_result(pr: ParseResult(a)) {
  case pr {
    Ok(pr) -> {
      let #(unparsed, parsed) = pr
      io.debug(#(str_to_string(unparsed), parsed))
      Nil
    }
    Error(e) -> io.println("ERROR: " <> e)
  }
}

fn item() -> Parser(Char) {
  Parser(fn(input) {
    case input {
      [] -> Error("Empty")
      [x, ..xs] -> Ok(#(xs, x))
    }
  })
}

fn sat(f: fn(Char) -> Bool) -> Parser(Char) {
  use x <- bind(item())
  case f(x) {
    True -> return(x)
    False -> empty()
  }
}

fn char_p(x) -> Parser(Char) {
  sat(curry2(char.eq)(x))
}

pub fn str_p(xs: Str) -> Parser(Str) {
  xs |> list.map(char_p) |> sequence_a
}

fn null_p() -> Parser(JsonValue) {
  str_p(str("null")) |> fmap(fn(_) { JsonNull })
}

fn bool_p() -> Parser(JsonValue) {
  str_p(str("true"))
  |> or(str_p(str("false")))
  |> fmap(fn(s) {
    case str_to_string(s) {
      "true" -> JsonBool(True)
      "false" -> JsonBool(False)
      _ -> panic as "not reachable"
    }
  })
}

fn not_null_p(p: Parser(List(a))) -> Parser(List(a)) {
  let Parser(p) = p
  Parser(fn(input) {
    use #(input_1, xs) <- result.then(p(input))
    case list.is_empty(xs) {
      True -> Error("Empty")
      False -> Ok(#(input_1, xs))
    }
  })
}

fn digit_p() -> Parser(Char) {
  sat(char.char_is_digit)
}

fn nat_p() -> Parser(Int) {
  use xs <- bind(some(digit_p()))
  return(xs |> str_to_int)
}

fn float_pos_p() {
  use integral <- bind(some(digit_p()))
  use _ <- bind(char_p(char(".")))
  use decimal <- bind(some(digit_p()))
  let x = str_to_string(integral) <> "." <> str_to_string(decimal)
  let assert Ok(res) =
    x |> float.parse |> result.map_error(fn(_) { "cannot parse float" })
  return(res)
}

fn float_p() -> Parser(Float) {
  fn() {
    use _ <- bind(char_p(char("-")))
    use n <- bind(float_pos_p())
    return(float.negate(n))
  }()
  |> or(float_pos_p())
}

fn int_p() -> Parser(Int) {
  fn() {
    use _ <- bind(char_p(char("-")))
    use n <- bind(nat_p())
    return(-n)
  }()
  |> or(nat_p())
}

fn number_p() -> Parser(JsonValue) {
  float_p()
  |> or(int_p() |> fmap(int.to_float))
  |> fmap(JsonNumber)
}

fn string_literal_p() -> Parser(Str) {
  Parser(fn(input) {
    let #(x, rest) =
      input |> list.split_while(fn(x) { !char.eq(x, char("\"")) })
    Ok(#(rest, x))
  })
}

fn string_p_() -> Parser(String) {
  char_p(char("\""))
  |> drop_left(string_literal_p())
  |> drop_right(char_p(char("\"")))
  |> fmap(str_to_string)
}

fn string_p() -> Parser(JsonValue) {
  string_p_() |> fmap(JsonString)
}

fn is_space(s: String) -> Bool {
  [" ", "\n", "\t", "\r"] |> list.any(fn(x) { x == s })
}

fn char_is_space(c: Char) -> Bool {
  c |> char_to_string |> is_space
}

fn whitespace_p() -> Parser(List(Char)) {
  span_p(char_is_space)
}

fn sep_p() -> Parser(Char) {
  use _ <- bind(whitespace_p())
  use x <- bind(char_p(char(",")))
  use _ <- bind(whitespace_p())
  return(x)
}

fn sep_by(sep: Parser(a), element: Parser(b)) -> Parser(List(b)) {
  fn() {
    use x <- bind(element)
    use xs <- bind(
      many(fn() {
        use _ <- bind(sep)
        use x <- bind(element)
        return(x)
      }()),
    )
    return([x, ..xs])
  }()
  |> or(pure([]))
}

fn array_p() -> Parser(JsonValue) {
  use _ <- bind(char_p(char("[")))
  use _ <- bind(whitespace_p())
  use elems <- bind(sep_by(sep_p(), json_p()))
  use _ <- bind(whitespace_p())
  use _ <- bind(char_p(char("]")))
  return(JsonArray(elems))
}

// FIXME: causes infinite loop
fn array_p_ap() -> Parser(JsonValue) {
  char_p(char("["))
  |> drop_left(whitespace_p())
  |> drop_left(sep_by(sep_p(), json_p()))
  |> drop_right(whitespace_p())
  |> drop_right(char_p(char("]")))
  |> fmap(JsonArray)
}

fn token_p(p: Parser(a)) -> Parser(a) {
  use _ <- bind(whitespace_p())
  use x <- bind(p)
  use _ <- bind(whitespace_p())
  return(x)
}

pub fn object_literal_p() -> Parser(#(String, JsonValue)) {
  use key <- bind(string_p_())
  use _ <- bind(token_p(char_p(char(":"))))
  use val <- bind(json_p())
  return(#(key, val))
}

pub fn object_p() -> Parser(JsonValue) {
  use _ <- bind(token_p(char_p(char("{"))))
  use pairs <- bind(sep_by(token_p(char_p(char(","))), object_literal_p()))
  use _ <- bind(token_p(char_p(char("}"))))
  return(JsonObject(pairs))
}

pub fn json_p() -> Parser(JsonValue) {
  null_p()
  |> or(bool_p())
  |> or(number_p())
  |> or(string_p())
  |> or(array_p())
  |> or(object_p())
}

pub fn parse(input: String) {
  let Parser(p) = json_p()
  p(str(input))
}

pub fn main() {
  let Parser(parse) = json_p()
  let res = parse(str("[[1, [\"hello\"], 1], false, -123 ,  55555]"))
  print_parse_result(res)
  io.debug(result.is_ok(res))
  io.println("")
  io.println("")
  let Parser(parse) = json_p()
  print_parse_result(res)
  io.debug(result.is_ok(res))
}
