import char.{
  type Char, type Str, char, char_to_string, str, str_to_int, str_to_string,
}
import gleam/function.{curry2, curry3}
import gleam/io
import gleam/list
import parser.{
  type ParseResult, type Parser, Parser, ap, bind, empty, fmap, many, or, pure,
  return, some,
}

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

fn digit_p() -> Parser(Char) {
  sat(char.char_is_digit)
}

fn string_p(s: Str) -> Parser(Str) {
  case s {
    [] -> return([])
    [x, ..xs] -> {
      use _ <- bind(char_p(x))
      use _ <- bind(string_p(xs))
      return([x, ..xs])
    }
  }
}

fn symbol_p(s: Str) -> Parser(Str) {
  token_p(string_p(s))
}

fn nat_p() -> Parser(Int) {
  use xs <- bind(some(digit_p()))
  return(xs |> str_to_int)
}

fn natural_p() -> Parser(Int) {
  token_p(nat_p())
}

fn int_p() -> Parser(Int) {
  fn() {
    use _ <- bind(char_p(char("-")))
    use n <- bind(nat_p())
    return(-n)
  }()
  |> or(nat_p())
}

// space :: Parser ()
// space = do many (sat isSpace)
// return ()

fn is_space(s: String) -> Bool {
  [" ", "\n", "\t"] |> list.any(fn(x) { x == s })
}

fn char_is_space(c: Char) -> Bool {
  c |> char_to_string |> is_space
}

fn space_p() -> Parser(Nil) {
  use _ <- bind(many(sat(char_is_space)))
  return(Nil)
}

fn token_p(p: Parser(a)) -> Parser(a) {
  use _ <- bind(space_p())
  use x <- bind(p)
  use _ <- bind(space_p())
  return(x)
}

fn expr() -> Parser(Int) {
  use t <- bind(term())
  fn() {
    use _ <- bind(symbol_p(str("+")))
    use e <- bind(expr())
    return(t + e)
  }()
  |> or(return(t))
}

fn term() -> Parser(Int) {
  use f <- bind(factor())
  fn() {
    use _ <- bind(symbol_p(str("*")))
    use t <- bind(term())
    return(f * t)
  }()
  |> or(return(f))
}

fn factor() -> Parser(Int) {
  fn() {
    use _x <- bind(symbol_p(str("(")))
    use e <- bind(expr())
    use _ <- bind(symbol_p(str(")")))
    return(e)
  }()
  |> or(natural_p())
}

pub fn main() {
  let Parser(parse) = expr()
  print_parse_result(parse(str("2 * (4*4+4)")))
}
