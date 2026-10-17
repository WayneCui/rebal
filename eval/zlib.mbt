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
fn perform_compress(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  if method_name(env, args[1], "compress") == "zip" {
    zip_compress(args[0], active)
  } else {
    let window = press_window(env, args[1], "compress")
    let level = compress_level(env, args, active)
    let bytes = payload_bytes(args[0], "compress")
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
fn compress_level(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> Int raise EvalError {
  let mut custom = false
  for sym in active {
    if env.symbols.canon(sym) == "level" {
      custom = true
    } else {
      raise EvalError::Cannot("compress")
    }
  }
  if !custom {
    -1
  } else {
    match args[2] {
      @value.Integer(n) if n >= 0L && n <= 9L => n.to_int()
      _ => raise EvalError::Cannot("compress")
    }
  }
}

///|
/// Decompresses a zlib, raw deflate, gzip, or stored zip binary.
fn perform_decompress(
  env : Env,
  data : @value.Cell,
  kind : @value.Cell,
) -> @value.Cell raise EvalError {
  if method_name(env, kind, "decompress") == "zip" {
    zip_decompress(data)
  } else {
    let window = press_window(env, kind, "decompress")
    match data {
      @value.Seq(series, index) if series.datatype() == @value.Binary => {
        let bytes = bytes_from(series, index)
        let plain = c_zlib_decompress(latin_text(bytes), bytes.length(), window)
        if c_zlib_code() != 0 {
          raise EvalError::Cannot("decompress")
        }
        binary_cell(codes_of(plain))
      }
      _ => raise EvalError::Cannot("decompress")
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
