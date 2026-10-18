///|
priv struct SaveField {
  spelling : String
  canon : String
  mut value : @value.Cell
}

///|
/// `/header` writes `REBOL [ fields ]` in front of the script.
/// `checksum:` becomes the SHA1 of the molded script, before compression.
/// `options: [compress]` compresses the bytes that follow the header.
fn save_with_header(
  env : Env,
  script : String,
  spec : @value.Cell,
  mode : @value.Cell?,
) -> Array[Int] raise EvalError {
  let plain = utf8_bytes(script)
  let fields = header_fields(env, spec)
  let compressing = header_apply_compress(env, fields, mode)
  let lines = header_mold(fields, plain)
  save_cat(
    header_text(lines),
    header_body(env, script, plain, mode, compressing),
  )
}

///|
fn header_fields(
  env : Env,
  spec : @value.Cell,
) -> Array[SaveField] raise EvalError {
  match block_items(spec) {
    None => raise EvalError::Cannot("save")
    Some(items) => {
      let fields : Array[SaveField] = []
      let mut index = 0
      while index + 1 < items.length() {
        match items[index] {
          @value.Sym(@value.SetWord, lexeme) => {
            fields.push({
              spelling: lexeme.spelling(),
              canon: env.symbols.canon(lexeme.sym()),
              value: items[index + 1],
            })
            index = index + 2
          }
          _ => index = index + 1
        }
      }
      fields
    }
  }
}

///|
/// `/compress false` drops the word. Any other `/compress` argument adds it.
/// The body is compressed only when the word is still in `options`.
fn header_apply_compress(
  env : Env,
  fields : Array[SaveField],
  mode : @value.Cell?,
) -> Bool raise EvalError {
  match mode {
    None => ()
    Some(chosen) =>
      if chosen is @value.Logic(false) {
        header_drop_compress(env, fields)
      } else if header_method(chosen) {
        if !header_options_block(fields) {
          header_set_options(fields, compress_block(env))
        } else if !header_has_compress(env, fields) {
          header_set_options(fields, header_add_compress(env, fields))
        }
      } else {
        raise EvalError::Cannot("save")
      }
  }
  header_has_compress(env, fields)
}

///|
fn header_method(chosen : @value.Cell) -> Bool {
  match chosen {
    @value.Logic(true) => true
    @value.Sym(@value.Word, _) => true
    _ => false
  }
}

///|
fn header_mold(
  fields : Array[SaveField],
  script : Array[Int],
) -> Array[(String, String)] {
  let lines : Array[(String, String)] = []
  let digest = checksum_mold(sha1(script))
  for field in fields {
    let molded = if field.canon == "checksum" {
      digest
    } else {
      @mold.mold_text(field.value)
    }
    lines.push((field.spelling, molded))
  }
  lines
}

///|
fn header_text(lines : Array[(String, String)]) -> String {
  if lines.length() == 0 {
    "REBOL []\n"
  } else {
    let buf = StringBuilder()
    buf.write_string("REBOL [\n")
    for line in lines {
      buf.write_string("    ")
      buf.write_string(line.0)
      buf.write_string(": ")
      buf.write_string(line.1)
      buf.write_char('\n')
    }
    buf.write_string("]\n")
    buf.to_string()
  }
}

///|
fn header_body(
  env : Env,
  script : String,
  plain : Array[Int],
  mode : @value.Cell?,
  compressing : Bool,
) -> Array[Int] raise EvalError {
  if !compressing {
    plain
  } else {
    let packed = save_zlib(script)
    if header_script_word(env, mode) {
      utf8_bytes("64#{" + encode_base64(packed, false) + "}")
    } else {
      packed
    }
  }
}

///|
fn header_script_word(env : Env, mode : @value.Cell?) -> Bool {
  match mode {
    Some(@value.Sym(@value.Word, lexeme)) =>
      env.symbols.canon(lexeme.sym()) == "script"
    _ => false
  }
}

///|
fn header_options(fields : Array[SaveField]) -> Int? {
  let mut found : Int? = None
  let mut index = 0
  while found is None && index < fields.length() {
    if fields[index].canon == "options" {
      found = Some(index)
    }
    index = index + 1
  }
  found
}

///|
fn header_options_block(fields : Array[SaveField]) -> Bool {
  match header_options(fields) {
    Some(index) => block_items(fields[index].value) is Some(_)
    None => false
  }
}

///|
fn header_has_compress(env : Env, fields : Array[SaveField]) -> Bool {
  match header_options(fields) {
    Some(index) =>
      match block_items(fields[index].value) {
        Some(items) => {
          let mut found = false
          for item in items {
            if word_is(env, item, "compress") {
              found = true
            }
          }
          found
        }
        None => false
      }
    None => false
  }
}

///|
fn header_set_options(fields : Array[SaveField], value : @value.Cell) -> Unit {
  match header_options(fields) {
    Some(index) => fields[index].value = value
    None => fields.push({ spelling: "options", canon: "options", value, })
  }
}

///|
fn header_drop_compress(env : Env, fields : Array[SaveField]) -> Unit {
  match header_options(fields) {
    Some(index) =>
      match block_items(fields[index].value) {
        Some(items) => {
          let block = @value.Series::block()
          for item in items {
            if !word_is(env, item, "compress") {
              block.push_item(item) |> ignore
            }
          }
          fields[index].value = @value.Seq(block, 0)
        }
        None => ()
      }
    None => ()
  }
}

///|
fn header_add_compress(env : Env, fields : Array[SaveField]) -> @value.Cell {
  let block = @value.Series::block()
  match header_options(fields) {
    Some(index) =>
      match block_items(fields[index].value) {
        Some(items) =>
          for item in items {
            block.push_item(item) |> ignore
          }
        None => ()
      }
    None => ()
  }
  block.push_item(compress_word(env)) |> ignore
  @value.Seq(block, 0)
}

///|
fn compress_block(env : Env) -> @value.Cell {
  let block = @value.Series::block()
  block.push_item(compress_word(env)) |> ignore
  @value.Seq(block, 0)
}

///|
fn compress_word(env : Env) -> @value.Cell {
  @value.Sym(
    @value.Word,
    @value.Lexeme::make(env.symbols.intern("compress"), "compress"),
  )
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
