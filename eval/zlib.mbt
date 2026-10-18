///|
#borrow(data)
extern "C" fn c_zlib_compress(
  data : String,
  len : Int,
  level : Int,
  window : Int,
) -> String = "rebal_zlib_compress"

///|
extern "C" fn c_zlib_code() -> Int = "rebal_zlib_code"

///|
#borrow(data)
extern "C" fn c_zlib_decompress(
  data : String,
  len : Int,
  window : Int,
) -> String = "rebal_zlib_decompress"

///|
/// Compresses a string or a binary. The method word is `zlib`, `deflate`,
/// `gzip`, or `zip`.
/// `save` of a `.gz` file compresses a binary. Anything else is refused.
fn gzip_saved(value : @value.Cell) -> Array[Int] raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      gzip_pack(bytes_from(series, index))
    _ => raise EvalError::Caused("expect-arg", "encode")
  }
}

///|
fn gzip_pack(bytes : Array[Int]) -> Array[Int] raise EvalError {
  let packed = c_zlib_compress(latin_text(bytes), bytes.length(), -1, 31)
  if c_zlib_code() != 0 {
    raise EvalError::Cannot("save")
  }
  codes_of(packed)
}

///|
fn gzip_unpack(bytes : Array[Int]) -> Array[Int] raise EvalError {
  let plain = c_zlib_decompress(latin_text(bytes), bytes.length(), 31)
  if c_zlib_code() != 0 {
    raise EvalError::Cannot("load")
  }
  codes_of(plain)
}

///|
fn perform_compress(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  if method_name(env, args[1], "compress") == "zip" {
    zip_compress(args[0], active)
  } else {
    let window = press_window(env, args[1], "compress")
    let (part, level) = compress_options(env, args, active)
    let bytes = ranged_payload(args[0], part, "compress")
    let packed = c_zlib_compress(
      latin_text(bytes),
      bytes.length(),
      level,
      window,
    )
    if c_zlib_code() != 0 {
      raise EvalError::Cannot("compress")
    }
    binary_cell(codes_of(packed))
  }
}

///|
fn compress_options(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> (Int?, Int) raise EvalError {
  let mut part : Int? = None
  let mut level = -1
  let mut cursor = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "part" {
      part = Some(part_count(args[0], args[cursor], "compress"))
      cursor = cursor + 1
    } else if name == "level" {
      level = level_number(args[cursor])
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("compress")
    }
  }
  (part, level)
}

///|
fn level_number(cell : @value.Cell) -> Int raise EvalError {
  match cell {
    @value.Integer(n) if n >= 0L && n <= 9L => n.to_int()
    _ => raise EvalError::Cannot("compress")
  }
}

///|
/// Decompresses a zlib, raw deflate, gzip, or stored zip binary.
/// `/part` limits the compressed bytes. `/size` must be the real length.
fn perform_decompress(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let (part, size) = decompress_options(env, args, active)
  let bytes = ranged_payload(args[0], part, "decompress")
  if method_name(env, args[1], "decompress") == "zip" {
    if size is Some(_) {
      raise EvalError::Cannot("decompress")
    }
    zip_block(bytes)
  } else {
    let window = press_window(env, args[1], "decompress")
    let plain = c_zlib_decompress(latin_text(bytes), bytes.length(), window)
    if c_zlib_code() != 0 {
      raise EvalError::Cannot("decompress")
    }
    let codes = codes_of(plain)
    match size {
      Some(expected) if codes.length() != expected =>
        raise EvalError::Cannot("decompress")
      _ => binary_cell(codes)
    }
  }
}

///|
fn decompress_options(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> (Int?, Int?) raise EvalError {
  let mut part : Int? = None
  let mut size : Int? = None
  let mut cursor = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "part" {
      part = Some(part_count(args[0], args[cursor], "decompress"))
      cursor = cursor + 1
    } else if name == "size" {
      size = Some(size_count(args[cursor]))
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("decompress")
    }
  }
  (part, size)
}

///|
fn size_count(cell : @value.Cell) -> Int raise EvalError {
  match cell {
    @value.Integer(n) if n >= 0L => n.to_int()
    _ => raise EvalError::Cannot("decompress")
  }
}

///|
fn part_count(
  data : @value.Cell,
  limit : @value.Cell,
  action : String,
) -> Int raise EvalError {
  match limit {
    @value.Integer(n) => n.to_int()
    @value.Decimal(n) => n.to_int64().to_int()
    @value.Seq(mark, mark_index) =>
      match data {
        @value.Seq(origin, origin_index) if physical_equal(mark, origin) =>
          mark_index - origin_index
        _ => raise EvalError::Cannot(action)
      }
    _ => raise EvalError::Cannot(action)
  }
}

///|
fn ranged_payload(
  cell : @value.Cell,
  part : Int?,
  action : String,
) -> Array[Int] raise EvalError {
  match cell {
    @value.Seq(series, index) if @value.text_series(series.datatype()) => {
      let (start, count) = part_span(index, series.length(), part)
      let buf = StringBuilder()
      for cursor in start..<(start + count) {
        match series.code(cursor) {
          Some(code) =>
            match code.to_char() {
              Some(char) => buf.write_char(char)
              None => ()
            }
          None => ()
        }
      }
      utf8_bytes(buf.to_string())
    }
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let (start, count) = part_span(index, series.length(), part)
      let bytes : Array[Int] = []
      for cursor in start..<(start + count) {
        match series.byte_at(cursor) {
          Some(byte) => bytes.push(byte.to_int())
          None => ()
        }
      }
      bytes
    }
    _ => raise EvalError::Cannot(action)
  }
}

///|
fn part_span(index : Int, length : Int, part : Int?) -> (Int, Int) {
  let start0 = if index < 0 { 0 } else { index }
  let available = if start0 >= length { 0 } else { length - start0 }
  match part {
    None => (start0, available)
    Some(n) if n >= 0 => {
      let count = if n > available { available } else { n }
      (start0, count)
    }
    Some(n) => {
      let want = -n
      let back = if want > start0 { start0 } else { want }
      (start0 - back, back)
    }
  }
}

///|
fn method_name(
  env : Env,
  kind : @value.Cell,
  action : String,
) -> String raise EvalError {
  let word = as_word(kind, action)
  env.symbols.canon(word.sym())
}

///|
fn press_window(
  env : Env,
  kind : @value.Cell,
  action : String,
) -> Int raise EvalError {
  let word = as_word(kind, action)
  match env.symbols.canon(word.sym()) {
    "zlib" => 15
    "deflate" => -15
    "gzip" => 31
    _ => raise EvalError::Cannot(action)
  }
}

///|
fn codes_of(text : String) -> Array[Int] {
  let bytes : Array[Int] = []
  for char in text {
    bytes.push(char.to_int())
  }
  bytes
}
