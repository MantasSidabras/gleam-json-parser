import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub opaque type Char {
  Char(inner: String)
}

pub type Str =
  List(Char)

pub fn char(s: String) -> Char {
  case string.length(s) {
    1 -> Char(s)
    _ -> Char("")
  }
}

pub fn eq(a: Char, b: Char) -> Bool {
  let Char(a) = a
  let Char(b) = b
  a == b
}

pub fn str(s: String) -> Str {
  s |> string.split("") |> list.map(char)
}

pub fn char_to_string(c: Char) -> String {
  c.inner
}

pub fn str_to_string(s: Str) -> String {
  s |> list.map(char_to_string) |> string.concat
}

pub fn char_is_digit(c: Char) -> Bool {
  c
  |> char_to_string
  |> int.parse
  |> result.is_ok
}

pub fn str_to_int(s: Str) -> Int {
  s
  |> str_to_string
  |> int.parse
  |> result.lazy_unwrap(fn() {
    str_to_string(s) |> io.debug
    panic as { "not a valid int" <> str_to_string(s) }
  })
}
