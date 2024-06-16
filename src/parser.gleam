import char.{type Char, type Str}
import gleam/function.{curry2}
import gleam/list
import gleam/result

pub type ParseError =
  String

pub type ParseResult(a) =
  Result(#(Str, a), ParseError)

pub type Parser(a) {
  Parser(fn(Str) -> ParseResult(a))
}

// Functor
pub fn fmap(p: Parser(a), f: fn(a) -> b) -> Parser(b) {
  let Parser(pf) = p
  Parser(fn(input) {
    use #(input_, x) <- result.map(pf(input))
    #(input_, f(x))
  })
}

// Functor
pub fn pure(x: a) -> Parser(a) {
  Parser(fn(input) { Ok(#(input, x)) })
}

pub const return = pure

// Applicative
pub fn ap(pf: Parser(fn(a) -> b), pa: Parser(a)) -> Parser(b) {
  let Parser(f) = pf
  let Parser(a) = pa
  Parser(fn(input) {
    case f(input) {
      Ok(#(input1, func)) -> {
        case a(input1) {
          Ok(#(input2, value)) -> Ok(#(input2, func(value)))
          Error(e) -> Error(e)
        }
      }
      Error(e) -> Error(e)
    }
  })
}

pub fn concat(head: a, tail: List(a)) -> List(a) {
  [head, ..tail]
}

// Applicative
pub fn traverse_a(xs: List(a), fx: fn(a) -> Parser(b)) -> Parser(List(b)) {
  list.fold_right(xs, pure([]), fn(acc, item) {
    pure(curry2(concat)) |> ap(fx(item)) |> ap(acc)
  })
}

// Applicative
pub fn sequence_a(xs: List(Parser(a))) -> Parser(List(a)) {
  traverse_a(xs, function.identity)
}

// Alternative empty
pub fn empty() -> Parser(a) {
  Parser(fn(_input) { Error("Empty") })
}

// Alternative <|>
pub fn or(p1: Parser(a), p2: Parser(a)) -> Parser(a) {
  let Parser(p1) = p1
  let Parser(p2) = p2
  Parser(fn(input) { p1(input) |> result.or(p2(input)) })
}

pub fn span_p(predicate: fn(Char) -> Bool) -> Parser(Str) {
  Parser(fn(input) {
    let #(token, rest) = list.split_while(input, predicate)
    Ok(#(rest, token))
  })
}

// Applicative (*>)
pub fn drop_left(p1: Parser(a), p2: Parser(b)) -> Parser(b) {
  pure(curry2(fn(_, b) { b })) |> ap(p1) |> ap(p2)
}

// Applicative (<*)
pub fn drop_right(p1: Parser(a), p2: Parser(b)) -> Parser(a) {
  pure(curry2(fn(a, _) { a })) |> ap(p1) |> ap(p2)
}

pub fn many(p: Parser(a)) -> Parser(List(a)) {
  Parser(fn(input) { parse_many(p, input, []) })
}

fn parse_many(p: Parser(a), input: Str, acc: List(a)) -> ParseResult(List(a)) {
  let Parser(pf) = p
  case pf(input) {
    Ok(#(remaining, result)) -> parse_many(p, remaining, [result, ..acc])
    Error(_) -> Ok(#(input, list.reverse(acc)))
  }
}

pub fn some(p: Parser(a)) -> Parser(List(a)) {
  Parser(fn(input: Str) -> ParseResult(List(a)) {
    let Parser(pf) = p
    case pf(input) {
      Ok(#(remaining, result)) -> {
        let many_parser = many(p)
        let Parser(many_parse_fn) = many_parser
        case many_parse_fn(remaining) {
          Ok(#(final_remaining, results)) ->
            Ok(#(final_remaining, [result, ..results]))
          Error(e) -> Error(e)
        }
      }
      Error(e) -> Error(e)
    }
  })
}

// Monad
pub fn bind(p: Parser(a), f: fn(a) -> Parser(b)) -> Parser(b) {
  let Parser(p) = p
  Parser(fn(input) {
    case p(input) {
      Error(e) -> Error(e)
      Ok(#(input_, res)) -> {
        let Parser(f_) = f(res)
        f_(input_)
      }
    }
  })
}
