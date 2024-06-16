import gleam/io
import json_parser
import simplifile

pub fn main() {
  let raw_content = simplifile.read(from: "./stuff.json")
  case raw_content {
    Ok(x) -> {
      let assert Ok(res) = json_parser.parse(x)
      io.debug(res)
      Nil
    }
    Error(e) -> {
      io.debug(e)
      Nil
    }
  }
}
