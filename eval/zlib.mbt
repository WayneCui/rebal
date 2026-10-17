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
/// Compresses a string or a binary. The method word is `zlib`, `deflate`, or `gzip`.
fn perform_compress(
  env : Env,
  data : @value.Cell,
  kind : @value.Cell,
) -> @value.Cell raise EvalError {
  let window = press_window(env, kind, "compress")
  let bytes = payload_bytes(data, "compress")
  let packed = c_zlib_compress(latin_text(bytes), bytes.length(), -1, window)
  if c_zlib_code() != 0 {
    raise EvalError::Cannot("compress")
  }
  binary_cell(codes_of(packed))
}

///|
/// Decompresses a zlib, raw deflate, or gzip binary.
fn perform_decompress(
  env : Env,
  data : @value.Cell,
  kind : @value.Cell,
) -> @value.Cell raise EvalError {
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
