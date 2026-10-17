///|
/// CRC-32 or Adler-32 of a string or a binary.
/// The result is the signed 32-bit residue, matching Rebol's integer.
fn perform_checksum(
  env : Env,
  data : @value.Cell,
  kind : @value.Cell,
) -> @value.Cell raise EvalError {
  let word = as_word(kind, "checksum")
  let bytes = payload_bytes(data, "checksum")
  let sum = match env.symbols.canon(word.sym()) {
    "crc32" => crc32(bytes)
    "adler32" => adler32(bytes)
    _ => raise EvalError::Cannot("checksum")
  }
  @value.Integer(sum)
}

///|
fn crc32(bytes : Array[Int]) -> Int64 {
  let mut crc = 0xFFFFFFFFL
  for byte in bytes {
    crc = (crc ^ byte.to_int64()) & 0xFFFFFFFFL
    for _ in 0..<8 {
      if crc % 2L == 1L {
        crc = ((crc / 2L) ^ 0xEDB88320L) & 0xFFFFFFFFL
      } else {
        crc = (crc / 2L) & 0xFFFFFFFFL
      }
    }
  }
  let sum = (crc ^ 0xFFFFFFFFL) & 0xFFFFFFFFL
  if sum >= 0x80000000L {
    sum - 0x100000000L
  } else {
    sum
  }
}

///|
fn adler32(bytes : Array[Int]) -> Int64 {
  let mut low = 1L
  let mut high = 0L
  for byte in bytes {
    low = (low + byte.to_int64()) % 65521L
    high = (high + low) % 65521L
  }
  let sum = (high * 65536L + low) & 0xFFFFFFFFL
  if sum >= 0x80000000L {
    sum - 0x100000000L
  } else {
    sum
  }
}
