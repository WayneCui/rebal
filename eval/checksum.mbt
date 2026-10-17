///|
/// CRC-32, Adler-32, MD5, SHA-1, or SHA-256 of a string or a binary.
/// The two CRCs are signed 32-bit integers. The hashes are raw digests.
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
    "sha256" => binary_cell(sha256(bytes))
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

///|
fn sha256(bytes : Array[Int]) -> Array[Int] {
  let padded = pad_sha1(bytes)
  let mut h0 = 0x6A09E667L
  let mut h1 = 0xBB67AE85L
  let mut h2 = 0x3C6EF372L
  let mut h3 = 0xA54FF53AL
  let mut h4 = 0x510E527FL
  let mut h5 = 0x9B05688CL
  let mut h6 = 0x1F83D9ABL
  let mut h7 = 0x5BE0CD19L
  let terms = sha256_terms()
  let mut offset = 0
  while offset < padded.length() {
    let words = sha256_schedule(padded, offset)
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    let mut f = h5
    let mut g = h6
    let mut h = h7
    for i in 0..<64 {
      let upper = rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25)
      let choose = (e & f) ^ (e.lnot() & g)
      let t1 = add32(add32(add32(h, upper), choose), add32(terms[i], words[i]))
      let lower = rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22)
      let majority = (a & b) ^ (a & c) ^ (b & c)
      let t2 = add32(lower, majority)
      h = g
      g = f
      f = e
      e = add32(d, t1)
      d = c
      c = b
      b = a
      a = add32(t1, t2)
    }
    h0 = add32(h0, a)
    h1 = add32(h1, b)
    h2 = add32(h2, c)
    h3 = add32(h3, d)
    h4 = add32(h4, e)
    h5 = add32(h5, f)
    h6 = add32(h6, g)
    h7 = add32(h7, h)
    offset = offset + 64
  }
  let out : Array[Int] = []
  push_be32(out, h0)
  push_be32(out, h1)
  push_be32(out, h2)
  push_be32(out, h3)
  push_be32(out, h4)
  push_be32(out, h5)
  push_be32(out, h6)
  push_be32(out, h7)
  out
}

///|
fn sha256_schedule(msg : Array[Int], offset : Int) -> Array[Int64] {
  let words : Array[Int64] = []
  for i in 0..<16 {
    let at = offset + i * 4
    let word = (msg[at].to_int64() << 24) |
      (msg[at + 1].to_int64() << 16) |
      (msg[at + 2].to_int64() << 8) |
      msg[at + 3].to_int64()
    words.push(word & 0xFFFFFFFFL)
  }
  for i in 16..<64 {
    let earlier = words[i - 15]
    let recent = words[i - 2]
    let small = rotr32(earlier, 7) ^ rotr32(earlier, 18) ^ (earlier >> 3)
    let large = rotr32(recent, 17) ^ rotr32(recent, 19) ^ (recent >> 10)
    words.push(add32(add32(words[i - 16], small), add32(words[i - 7], large)))
  }
  words
}

///|
fn rotr32(value : Int64, bits : Int) -> Int64 {
  let kept = value & 0xFFFFFFFFL
  ((kept >> bits) | (kept << (32 - bits))) & 0xFFFFFFFFL
}

///|
fn sha256_terms() -> Array[Int64] {
  [
    0x428A2F98L, 0x71374491L, 0xB5C0FBCFL, 0xE9B5DBA5L, 0x3956C25BL, 0x59F111F1L,
    0x923F82A4L, 0xAB1C5ED5L, 0xD807AA98L, 0x12835B01L, 0x243185BEL, 0x550C7DC3L,
    0x72BE5D74L, 0x80DEB1FEL, 0x9BDC06A7L, 0xC19BF174L, 0xE49B69C1L, 0xEFBE4786L,
    0x0FC19DC6L, 0x240CA1CCL, 0x2DE92C6FL, 0x4A7484AAL, 0x5CB0A9DCL, 0x76F988DAL,
    0x983E5152L, 0xA831C66DL, 0xB00327C8L, 0xBF597FC7L, 0xC6E00BF3L, 0xD5A79147L,
    0x06CA6351L, 0x14292967L, 0x27B70A85L, 0x2E1B2138L, 0x4D2C6DFCL, 0x53380D13L,
    0x650A7354L, 0x766A0ABBL, 0x81C2C92EL, 0x92722C85L, 0xA2BFE8A1L, 0xA81A664BL,
    0xC24B8B70L, 0xC76C51A3L, 0xD192E819L, 0xD6990624L, 0xF40E3585L, 0x106AA070L,
    0x19A4C116L, 0x1E376C08L, 0x2748774CL, 0x34B0BCB5L, 0x391C0CB3L, 0x4ED8AA4AL,
    0x5B9CCA4FL, 0x682E6FF3L, 0x748F82EEL, 0x78A5636FL, 0x84C87814L, 0x8CC70208L,
    0x90BEFFFAL, 0xA4506CEBL, 0xBEF9A3F7L, 0xC67178F2L,
  ]
}
