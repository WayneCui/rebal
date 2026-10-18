///|
/// ustar archives. The block is `[name [data header extra] ...]`.
/// `name` is a file. `header` is the pre-POSIX fields. `extra` is the ustar
/// fields, or none when the magic is absent. `/only` keeps the named members.
fn decode_tar(
  value : @value.Cell,
  only : Bool,
  only_value : @value.Cell,
) -> @value.Cell raise EvalError {
  let bytes = payload_bytes(value, "decode")
  let result = @value.Series::block()
  let mut at = 0
  let mut reading = true
  while reading && at + 512 <= bytes.length() {
    if tar_end(bytes, at) {
      reading = false
    } else {
      let name = tar_member_name(bytes, at)
      let size = tar_size(bytes, at)
      if at + 512 + size > bytes.length() {
        raise EvalError::Cannot("decode")
      }
      if tar_wanted(only, only_value, name) {
        result.push_item(tar_file(name)) |> ignore
        result.push_item(tar_member(bytes, at, size)) |> ignore
      }
      at = tar_advance(at, size)
    }
  }
  @value.Seq(result, 0)
}

///|
fn tar_member(bytes : Array[Int], at : Int, size : Int) -> @value.Cell {
  let body = @value.Series::block()
  body.push_item(binary_cell(tar_copy(bytes, at + 512, size))) |> ignore
  body.push_item(tar_header(bytes, at)) |> ignore
  body.push_item(tar_extra(bytes, at)) |> ignore
  @value.Seq(body, 0)
}

///|
fn tar_header(bytes : Array[Int], at : Int) -> @value.Cell {
  let block = @value.Series::block()
  block.push_item(text_series(tar_text(bytes, at, 100))) |> ignore
  block.push_item(text_series(tar_text(bytes, at + 100, 8))) |> ignore
  block.push_item(@value.Integer(tar_octal(bytes, at + 108, 8))) |> ignore
  block.push_item(@value.Integer(tar_octal(bytes, at + 116, 8))) |> ignore
  block.push_item(@value.Integer(tar_octal(bytes, at + 124, 12))) |> ignore
  block.push_item(@value.Integer(tar_octal(bytes, at + 136, 12))) |> ignore
  block.push_item(@value.Integer(tar_octal(bytes, at + 148, 8))) |> ignore
  block.push_item(@value.Integer(bytes[at + 156].to_int64())) |> ignore
  block.push_item(text_series(tar_text(bytes, at + 157, 100))) |> ignore
  @value.Seq(block, 0)
}

///|
fn tar_extra(bytes : Array[Int], at : Int) -> @value.Cell {
  if !tar_ustar(bytes, at) {
    @value.Cell::None
  } else {
    let block = @value.Series::block()
    block.push_item(text_series(tar_text(bytes, at + 257, 6))) |> ignore
    block.push_item(text_series(tar_text(bytes, at + 263, 2))) |> ignore
    block.push_item(text_series(tar_text(bytes, at + 265, 32))) |> ignore
    block.push_item(text_series(tar_text(bytes, at + 297, 32))) |> ignore
    block.push_item(text_series(tar_text(bytes, at + 329, 8))) |> ignore
    block.push_item(text_series(tar_text(bytes, at + 337, 8))) |> ignore
    block.push_item(text_series(tar_text(bytes, at + 345, 155))) |> ignore
    @value.Seq(block, 0)
  }
}

///|
fn tar_member_name(bytes : Array[Int], at : Int) -> String {
  let name = tar_text(bytes, at, 100)
  if tar_ustar(bytes, at) {
    let prefix = tar_text(bytes, at + 345, 155)
    if prefix != "" {
      prefix + name
    } else {
      name
    }
  } else {
    name
  }
}

///|
fn tar_end(bytes : Array[Int], at : Int) -> Bool {
  tar_text(bytes, at, 100) == "" &&
  tar_text(bytes, at + 157, 100) == "" &&
  tar_octal(bytes, at + 124, 12) == 0L &&
  tar_octal(bytes, at + 136, 12) == 0L &&
  bytes[at + 156] == 0
}

///|
fn tar_size(bytes : Array[Int], at : Int) -> Int raise EvalError {
  let size = tar_octal(bytes, at + 124, 12)
  if size < 0L || size > 2147483647L {
    raise EvalError::Cannot("decode")
  }
  size.to_int()
}

///|
fn tar_advance(at : Int, size : Int) -> Int {
  let mut next = at + 512 + size
  let rest = size % 512
  if size > 0 && rest != 0 {
    next = next + 512 - rest
  }
  next
}

///|
fn tar_ustar(bytes : Array[Int], at : Int) -> Bool {
  bytes[at + 257] == 0x75 &&
  bytes[at + 258] == 0x73 &&
  bytes[at + 259] == 0x74 &&
  bytes[at + 260] == 0x61 &&
  bytes[at + 261] == 0x72 &&
  bytes[at + 262] == 0
}

///|
fn tar_text(bytes : Array[Int], at : Int, width : Int) -> String {
  let buf = StringBuilder()
  let mut index = 0
  let mut copying = true
  while copying && index < width {
    let byte = bytes[at + index]
    if byte == 0 {
      copying = false
    } else {
      buf.write_char(byte.to_char().unwrap())
      index = index + 1
    }
  }
  buf.to_string()
}

///|
fn tar_octal(bytes : Array[Int], at : Int, width : Int) -> Int64 {
  let mut index = 0
  while index < width &&
        (bytes[at + index] == 0 || bytes[at + index] == ' '.to_int()) {
    index = index + 1
  }
  let mut value = 0L
  while index < width {
    let byte = bytes[at + index]
    if byte >= '0'.to_int() && byte <= '7'.to_int() {
      value = value * 8L + (byte - '0'.to_int()).to_int64()
      index = index + 1
    } else {
      break
    }
  }
  value
}

///|
fn tar_copy(bytes : Array[Int], at : Int, size : Int) -> Array[Int] {
  let out : Array[Int] = []
  for index in 0..<size {
    out.push(bytes[at + index])
  }
  out
}

///|
fn tar_file(name : String) -> @value.Cell {
  let codes : Array[Int] = []
  for char in name {
    codes.push(char.to_int())
  }
  text_of_codes(@value.File, codes, 0, codes.length())
}

///|
fn tar_wanted(
  only : Bool,
  spec : @value.Cell,
  name : String,
) -> Bool raise EvalError {
  if !only {
    true
  } else {
    tar_listed(spec, name)
  }
}

///|
fn tar_listed(spec : @value.Cell, name : String) -> Bool raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let mut found = false
      for cursor in index..<series.length() {
        match series.item(cursor) {
          Some(item) => if tar_name_is(item, name) { found = true }
          None => ()
        }
      }
      found
    }
    _ => tar_name_is(spec, name)
  }
}

///|
fn tar_name_is(spec : @value.Cell, name : String) -> Bool raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.File ||
      series.datatype() == @value.String => text_from(series, index) == name
    _ => raise EvalError::Cannot("decode")
  }
}
