///|
/// CRC-32, Adler-32, MD5, or SHA-1 of a string or a binary.
/// The two CRCs are signed 32-bit integers. MD5 is 16 bytes and SHA-1 is 20.
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
    "md5" => binary_cell(md5(bytes))
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

///|
fn md5(bytes : Array[Int]) -> Array[Int] {
  let padded = pad_md5(bytes)
  let mut h0 = 0x67452301L
  let mut h1 = 0xEFCDAB89L
  let mut h2 = 0x98BADCFEL
  let mut h3 = 0x10325476L
  let shifts = md5_shifts()
  let terms = md5_terms()
  let mut offset = 0
  while offset < padded.length() {
    let words = md5_words(padded, offset)
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    for step in 0..<64 {
      let mixed = add32(
        add32(a, md5_mix(step, b, c, d)),
        add32(terms[step], words[md5_index(step)]),
      )
      let next = add32(b, rotl32(mixed, shifts[step]))
      a = d
      d = c
      c = b
      b = next
    }
    h0 = add32(h0, a)
    h1 = add32(h1, b)
    h2 = add32(h2, c)
    h3 = add32(h3, d)
    offset = offset + 64
  }
  let out : Array[Int] = []
  push_le32(out, h0)
  push_le32(out, h1)
  push_le32(out, h2)
  push_le32(out, h3)
  out
}

///|
fn pad_md5(bytes : Array[Int]) -> Array[Int] {
  let padded : Array[Int] = []
  for byte in bytes {
    padded.push(byte & 0xFF)
  }
  padded.push(0x80)
  while padded.length() % 64 != 56 {
    padded.push(0)
  }
  let bits = bytes.length().to_int64() << 3
  let mut shift = 0
  while shift <= 56 {
    padded.push(((bits >> shift) & 0xFFL).to_int())
    shift = shift + 8
  }
  padded
}

///|
fn md5_words(msg : Array[Int], offset : Int) -> Array[Int64] {
  let words : Array[Int64] = []
  for i in 0..<16 {
    let at = offset + i * 4
    let word = msg[at].to_int64() |
      (msg[at + 1].to_int64() << 8) |
      (msg[at + 2].to_int64() << 16) |
      (msg[at + 3].to_int64() << 24)
    words.push(word & 0xFFFFFFFFL)
  }
  words
}

///|
fn md5_index(step : Int) -> Int {
  if step < 16 {
    step
  } else if step < 32 {
    (5 * step + 1) % 16
  } else if step < 48 {
    (3 * step + 5) % 16
  } else {
    7 * step % 16
  }
}

///|
fn md5_mix(step : Int, b : Int64, c : Int64, d : Int64) -> Int64 {
  if step < 16 {
    (b & c) | (b.lnot() & d)
  } else if step < 32 {
    (b & d) | (d.lnot() & c)
  } else if step < 48 {
    b ^ c ^ d
  } else {
    c ^ (b | d.lnot())
  }
}

///|
fn md5_shifts() -> Array[Int] {
  [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5,
    9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16,
    23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
  ]
}

///|
fn md5_terms() -> Array[Int64] {
  [
    0xD76AA478L, 0xE8C7B756L, 0x242070DBL, 0xC1BDCEEEL, 0xF57C0FAFL, 0x4787C62AL,
    0xA8304613L, 0xFD469501L, 0x698098D8L, 0x8B44F7AFL, 0xFFFF5BB1L, 0x895CD7BEL,
    0x6B901122L, 0xFD987193L, 0xA679438EL, 0x49B40821L, 0xF61E2562L, 0xC040B340L,
    0x265E5A51L, 0xE9B6C7AAL, 0xD62F105DL, 0x02441453L, 0xD8A1E681L, 0xE7D3FBC8L,
    0x21E1CDE6L, 0xC33707D6L, 0xF4D50D87L, 0x455A14EDL, 0xA9E3E905L, 0xFCEFA3F8L,
    0x676F02D9L, 0x8D2A4C8AL, 0xFFFA3942L, 0x8771F681L, 0x6D9D6122L, 0xFDE5380CL,
    0xA4BEEA44L, 0x4BDECFA9L, 0xF6BB4B60L, 0xBEBFBC70L, 0x289B7EC6L, 0xEAA127FAL,
    0xD4EF3085L, 0x04881D05L, 0xD9D4D039L, 0xE6DB99E5L, 0x1FA27CF8L, 0xC4AC5665L,
    0xF4292244L, 0x432AFF97L, 0xAB9423A7L, 0xFC93A039L, 0x655B59C3L, 0x8F0CCC92L,
    0xFFEFF47DL, 0x85845DD1L, 0x6FA87E4FL, 0xFE2CE6E0L, 0xA3014314L, 0x4E0811A1L,
    0xF7537E82L, 0xBD3AF235L, 0x2AD7D2BBL, 0xEB86D391L,
  ]
}

///|
fn push_le32(out : Array[Int], word : Int64) -> Unit {
  out.push((word & 0xFFL).to_int())
  out.push(((word >> 8) & 0xFFL).to_int())
  out.push(((word >> 16) & 0xFFL).to_int())
  out.push(((word >> 24) & 0xFFL).to_int())
}
