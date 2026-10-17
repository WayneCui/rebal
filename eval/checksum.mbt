///|
/// CRC-32, Adler-32, or SHA-1 of a string or a binary.
/// The two CRCs are signed 32-bit integers. SHA-1 is a 20-byte binary.
fn perform_checksum(
  env : Env,
  data : @value.Cell,
  kind : @value.Cell,
) -> @value.Cell raise EvalError {
  let word = as_word(kind, "checksum")
  let bytes = payload_bytes(data, "checksum")
  match env.symbols.canon(word.sym()) {
    "crc32" => @value.Integer(crc32(bytes))
    "adler32" => @value.Integer(adler32(bytes))
    "sha1" => binary_cell(sha1(bytes))
    _ => raise EvalError::Cannot("checksum")
  }
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

///|
fn sha1(bytes : Array[Int]) -> Array[Int] {
  let padded = pad_sha1(bytes)
  let mut h0 = 0x67452301L
  let mut h1 = 0xEFCDAB89L
  let mut h2 = 0x98BADCFEL
  let mut h3 = 0x10325476L
  let mut h4 = 0xC3D2E1F0L
  let mut offset = 0
  while offset < padded.length() {
    let words = sha1_schedule(padded, offset)
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    for i in 0..<80 {
      let mixed = add32(add32(rotl32(a, 5), sha1_mix(i, b, c, d)), e)
      let temp = add32(mixed, add32(sha1_round(i), words[i]))
      e = d
      d = c
      c = rotl32(b, 30)
      b = a
      a = temp
    }
    h0 = add32(h0, a)
    h1 = add32(h1, b)
    h2 = add32(h2, c)
    h3 = add32(h3, d)
    h4 = add32(h4, e)
    offset = offset + 64
  }
  let out : Array[Int] = []
  push_be32(out, h0)
  push_be32(out, h1)
  push_be32(out, h2)
  push_be32(out, h3)
  push_be32(out, h4)
  out
}

///|
fn pad_sha1(bytes : Array[Int]) -> Array[Int] {
  let padded : Array[Int] = []
  for byte in bytes {
    padded.push(byte & 0xFF)
  }
  padded.push(0x80)
  while padded.length() % 64 != 56 {
    padded.push(0)
  }
  let bits = bytes.length().to_int64() << 3
  let mut shift = 56
  while shift >= 0 {
    padded.push(((bits >> shift) & 0xFFL).to_int())
    shift = shift - 8
  }
  padded
}

///|
fn sha1_schedule(msg : Array[Int], offset : Int) -> Array[Int64] {
  let words : Array[Int64] = []
  for i in 0..<16 {
    let at = offset + i * 4
    let word = (msg[at].to_int64() << 24) |
      (msg[at + 1].to_int64() << 16) |
      (msg[at + 2].to_int64() << 8) |
      msg[at + 3].to_int64()
    words.push(word & 0xFFFFFFFFL)
  }
  for i in 16..<80 {
    let mixed = words[i - 3] ^ words[i - 8] ^ words[i - 14] ^ words[i - 16]
    words.push(rotl32(mixed, 1))
  }
  words
}

///|
fn sha1_mix(round : Int, b : Int64, c : Int64, d : Int64) -> Int64 {
  if round < 20 {
    (b & c) | (b.lnot() & d)
  } else if round < 40 || round >= 60 {
    b ^ c ^ d
  } else {
    (b & c) | (b & d) | (c & d)
  }
}

///|
fn sha1_round(round : Int) -> Int64 {
  if round < 20 {
    0x5A827999L
  } else if round < 40 {
    0x6ED9EBA1L
  } else if round < 60 {
    0x8F1BBCDCL
  } else {
    0xCA62C1D6L
  }
}

///|
fn rotl32(value : Int64, bits : Int) -> Int64 {
  let kept = value & 0xFFFFFFFFL
  ((kept << bits) | (kept >> (32 - bits))) & 0xFFFFFFFFL
}

///|
fn add32(left : Int64, right : Int64) -> Int64 {
  (left + right) & 0xFFFFFFFFL
}

///|
fn push_be32(out : Array[Int], word : Int64) -> Unit {
  out.push(((word >> 24) & 0xFFL).to_int())
  out.push(((word >> 16) & 0xFFL).to_int())
  out.push(((word >> 8) & 0xFFL).to_int())
  out.push((word & 0xFFL).to_int())
}
