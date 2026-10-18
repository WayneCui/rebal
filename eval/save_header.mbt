///|
/// `/header` writes `REBOL [ fields ]` in front of the molded script.
/// A `checksum:` field is replaced by the SHA1 of that script.
fn save_with_header(
  env : Env,
  script : String,
  spec : @value.Cell,
) -> Array[Int] raise EvalError {
  let lines = header_lines(env, spec, utf8_bytes(script))
  let buf = StringBuilder()
  if lines.length() == 0 {
    buf.write_string("REBOL []\n")
  } else {
    buf.write_string("REBOL [\n")
    for line in lines {
      buf.write_string("    ")
      buf.write_string(line.0)
      buf.write_string(": ")
      buf.write_string(line.1)
      buf.write_char('\n')
    }
    buf.write_string("]\n")
  }
  buf.write_string(script)
  utf8_bytes(buf.to_string())
}

///|
fn header_lines(
  env : Env,
  spec : @value.Cell,
  script : Array[Int],
) -> Array[(String, String)] raise EvalError {
  match block_items(spec) {
    None => raise EvalError::Cannot("save")
    Some(items) => {
      let lines : Array[(String, String)] = []
      let digest = checksum_mold(sha1(script))
      let mut index = 0
      while index + 1 < items.length() {
        match items[index] {
          @value.Sym(@value.SetWord, lexeme) => {
            let molded = if env.symbols.canon(lexeme.sym()) == "checksum" {
              digest
            } else {
              @mold.mold_text(items[index + 1])
            }
            lines.push((lexeme.spelling(), molded))
            index = index + 2
          }
          _ => index = index + 1
        }
      }
      lines
    }
  }
}

///|
fn checksum_mold(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  buf.write_string("#{")
  for byte in bytes {
    buf.write_char(hex_digit(byte / 16))
    buf.write_char(hex_digit(byte % 16))
  }
  buf.write_char('}')
  buf.to_string()
}
