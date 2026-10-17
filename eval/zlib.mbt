///|
#borrow(data)
extern "C" fn c_zlib_compress(data : String, len : Int, level : Int) -> String = "rebal_zlib_compress"

///|
extern "C" fn c_zlib_code() -> Int = "rebal_zlib_code"

///|
#borrow(data)
extern "C" fn c_zlib_decompress(data : String, len : Int) -> String = "rebal_zlib_decompress"

///|
/// Compresses a string or a binary with zlib. The method word must be `zlib`.
fn perform_compress(
  env : Env,
  data : @value.Cell,
  kind : @value.Cell,
) -> @value.Cell raise EvalError {
  if !zlib_word(env, kind, "compress") {
    raise EvalError::Cannot("compress")
  }
  let bytes = payload_bytes(data, "compress")
  let packed = c_zlib_compress(latin_text(bytes), bytes.length(), -1)
  if c_zlib_code() != 0 {
    raise EvalError::Cannot("compress")
  }
  binary_cell(codes_of(packed))
}

///|
/// Decompresses a zlib binary. The method word must be `zlib`.
fn perform_decompress(
  env : Env,
  data : @value.Cell,
  kind : @value.Cell,
) -> @value.Cell raise EvalError {
  if !zlib_word(env, kind, "decompress") {
    raise EvalError::Cannot("decompress")
  }
  match data {
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let bytes = bytes_from(series, index)
      let plain = c_zlib_decompress(latin_text(bytes), bytes.length())
      if c_zlib_code() != 0 {
        raise EvalError::Cannot("decompress")
      }
      binary_cell(codes_of(plain))
    }
    _ => raise EvalError::Cannot("decompress")
  }
}

///|
fn zlib_word(
  env : Env,
  kind : @value.Cell,
  action : String,
) -> Bool raise EvalError {
  let word = as_word(kind, action)
  env.symbols.canon(word.sym()) == "zlib"
}

///|
fn codes_of(text : String) -> Array[Int] {
  let bytes : Array[Int] = []
  for char in text {
    bytes.push(char.to_int())
  }
  bytes
}
