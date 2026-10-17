///|
/// CRC-24, CRC-32, Adler-32, MD5, SHA-1, SHA-256, SHA-384, or SHA-512.
/// The CRCs are integers. The hashes are raw digests.
fn perform_checksum(
  env : Env,
  data : @value.Cell,
  kind : @value.Cell,
) -> @value.Cell raise EvalError {
  let word = as_word(kind, "checksum")
  let bytes = payload_bytes(data, "checksum")
  match env.symbols.canon(word.sym()) {
    "crc24" => @value.Integer(crc24(bytes))
    "crc32" => @value.Integer(crc32(bytes))
    "adler32" => @value.Integer(adler32(bytes))
    "sha1" => binary_cell(sha1(bytes))
    "md5" => binary_cell(md5(bytes))
    "sha256" => binary_cell(sha256(bytes))
    "sha384" => binary_cell(sha384(bytes))
    "sha512" => binary_cell(sha512(bytes))
    _ => raise EvalError::Cannot("checksum")
  }
}

///|
fn crc24(bytes : Array[Int]) -> Int64 {
  if bytes.length() == 0 {
    return 0L
  }
  let table = crc24_table()
  let mut crc = bytes.length().to_int64() + bytes[0].to_int64()
  for byte in bytes {
    let index = (((crc >> 16) ^ byte.to_int64()) & 0xFFL).to_int()
    crc = ((crc << 8) & 0xFFFFFFL) ^ table[index]
  }
  crc
}

///|
fn crc24_table() -> Array[Int64] {
  let table : Array[Int64] = []
  for ch in 0..<256 {
    table.push(crc24_entry(ch))
  }
  table
}

///|
fn crc24_entry(ch : Int) -> Int64 {
  let mut data = ch.to_int64() << 16
  let mut accum = 0L
  for _ in 0..<8 {
    let mixed = (data ^ accum) & 0x800000L
    if mixed != 0L {
      accum = ((accum << 1) ^ 0x864CFBL) & 0xFFFFFFL
    } else {
      accum = (accum << 1) & 0xFFFFFFL
    }
    data = (data << 1) & 0xFFFFFFL
  }
  accum
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

///|
fn sha512(bytes : Array[Int]) -> Array[Int] {
  wide_sha(
    bytes, 0x6A09E667F3BCC908UL, 0xBB67AE8584CAA73BUL, 0x3C6EF372FE94F82BUL, 0xA54FF53A5F1D36F1UL,
    0x510E527FADE682D1UL, 0x9B05688C2B3E6C1FUL, 0x1F83D9ABFB41BD6BUL, 0x5BE0CD19137E2179UL,
    8,
  )
}

///|
fn sha384(bytes : Array[Int]) -> Array[Int] {
  wide_sha(
    bytes, 0xCBBB9D5DC1059ED8UL, 0x629A292A367CD507UL, 0x9159015A3070DD17UL, 0x152FECD8F70E5939UL,
    0x67332667FFC00B31UL, 0x8EB44A8768581511UL, 0xDB0C2E0D64F98FA7UL, 0x47B5481DBEFA4FA4UL,
    6,
  )
}

///|
fn wide_sha(
  bytes : Array[Int],
  start0 : UInt64,
  start1 : UInt64,
  start2 : UInt64,
  start3 : UInt64,
  start4 : UInt64,
  start5 : UInt64,
  start6 : UInt64,
  start7 : UInt64,
  keep : Int,
) -> Array[Int] {
  let padded = pad_sha512(bytes)
  let mut h0 = start0
  let mut h1 = start1
  let mut h2 = start2
  let mut h3 = start3
  let mut h4 = start4
  let mut h5 = start5
  let mut h6 = start6
  let mut h7 = start7
  let terms = sha512_terms()
  let mut offset = 0
  while offset < padded.length() {
    let words = sha512_schedule(padded, offset)
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    let mut f = h5
    let mut g = h6
    let mut h = h7
    for i in 0..<80 {
      let upper = rotr64(e, 14) ^ rotr64(e, 18) ^ rotr64(e, 41)
      let choose = (e & f) ^ (e.lnot() & g)
      let t1 = h + upper + choose + terms[i] + words[i]
      let lower = rotr64(a, 28) ^ rotr64(a, 34) ^ rotr64(a, 39)
      let majority = (a & b) ^ (a & c) ^ (b & c)
      let t2 = lower + majority
      h = g
      g = f
      f = e
      e = d + t1
      d = c
      c = b
      b = a
      a = t1 + t2
    }
    h0 = h0 + a
    h1 = h1 + b
    h2 = h2 + c
    h3 = h3 + d
    h4 = h4 + e
    h5 = h5 + f
    h6 = h6 + g
    h7 = h7 + h
    offset = offset + 128
  }
  let words = [h0, h1, h2, h3, h4, h5, h6, h7]
  let out : Array[Int] = []
  for i in 0..<keep {
    push_be64(out, words[i])
  }
  out
}

///|
fn pad_sha512(bytes : Array[Int]) -> Array[Int] {
  let padded : Array[Int] = []
  for byte in bytes {
    padded.push(byte & 0xFF)
  }
  padded.push(0x80)
  while padded.length() % 128 != 112 {
    padded.push(0)
  }
  for _ in 0..<8 {
    padded.push(0)
  }
  let bits = bytes.length().to_uint64() << 3
  let mut shift = 56
  while shift >= 0 {
    padded.push(((bits >> shift) & 0xFFUL).to_int())
    shift = shift - 8
  }
  padded
}

///|
fn sha512_schedule(msg : Array[Int], offset : Int) -> Array[UInt64] {
  let words : Array[UInt64] = []
  for i in 0..<16 {
    words.push(be64(msg, offset + i * 8))
  }
  for i in 16..<80 {
    let earlier = words[i - 15]
    let recent = words[i - 2]
    let small = rotr64(earlier, 1) ^ rotr64(earlier, 8) ^ (earlier >> 7)
    let large = rotr64(recent, 19) ^ rotr64(recent, 61) ^ (recent >> 6)
    words.push(words[i - 16] + small + words[i - 7] + large)
  }
  words
}

///|
fn be64(msg : Array[Int], at : Int) -> UInt64 {
  let mut word = 0UL
  for i in 0..<8 {
    word = (word << 8) | msg[at + i].to_uint64()
  }
  word
}

///|
fn rotr64(value : UInt64, bits : Int) -> UInt64 {
  (value >> bits) | (value << (64 - bits))
}

///|
fn push_be64(out : Array[Int], word : UInt64) -> Unit {
  let mut shift = 56
  while shift >= 0 {
    out.push(((word >> shift) & 0xFFUL).to_int())
    shift = shift - 8
  }
}

///|
fn sha512_terms() -> Array[UInt64] {
  [
    0x428A2F98D728AE22UL, 0x7137449123EF65CDUL, 0xB5C0FBCFEC4D3B2FUL, 0xE9B5DBA58189DBBCUL,
    0x3956C25BF348B538UL, 0x59F111F1B605D019UL, 0x923F82A4AF194F9BUL, 0xAB1C5ED5DA6D8118UL,
    0xD807AA98A3030242UL, 0x12835B0145706FBEUL, 0x243185BE4EE4B28CUL, 0x550C7DC3D5FFB4E2UL,
    0x72BE5D74F27B896FUL, 0x80DEB1FE3B1696B1UL, 0x9BDC06A725C71235UL, 0xC19BF174CF692694UL,
    0xE49B69C19EF14AD2UL, 0xEFBE4786384F25E3UL, 0x0FC19DC68B8CD5B5UL, 0x240CA1CC77AC9C65UL,
    0x2DE92C6F592B0275UL, 0x4A7484AA6EA6E483UL, 0x5CB0A9DCBD41FBD4UL, 0x76F988DA831153B5UL,
    0x983E5152EE66DFABUL, 0xA831C66D2DB43210UL, 0xB00327C898FB213FUL, 0xBF597FC7BEEF0EE4UL,
    0xC6E00BF33DA88FC2UL, 0xD5A79147930AA725UL, 0x06CA6351E003826FUL, 0x142929670A0E6E70UL,
    0x27B70A8546D22FFCUL, 0x2E1B21385C26C926UL, 0x4D2C6DFC5AC42AEDUL, 0x53380D139D95B3DFUL,
    0x650A73548BAF63DEUL, 0x766A0ABB3C77B2A8UL, 0x81C2C92E47EDAEE6UL, 0x92722C851482353BUL,
    0xA2BFE8A14CF10364UL, 0xA81A664BBC423001UL, 0xC24B8B70D0F89791UL, 0xC76C51A30654BE30UL,
    0xD192E819D6EF5218UL, 0xD69906245565A910UL, 0xF40E35855771202AUL, 0x106AA07032BBD1B8UL,
    0x19A4C116B8D2D0C8UL, 0x1E376C085141AB53UL, 0x2748774CDF8EEB99UL, 0x34B0BCB5E19B48A8UL,
    0x391C0CB3C5C95A63UL, 0x4ED8AA4AE3418ACBUL, 0x5B9CCA4F7763E373UL, 0x682E6FF3D6B2B8A3UL,
    0x748F82EE5DEFB2FCUL, 0x78A5636F43172F60UL, 0x84C87814A1F0AB72UL, 0x8CC702081A6439ECUL,
    0x90BEFFFA23631E28UL, 0xA4506CEBDE82BDE9UL, 0xBEF9A3F7B2C67915UL, 0xC67178F2E372532BUL,
    0xCA273ECEEA26619CUL, 0xD186B8C721C0C207UL, 0xEADA7DD6CDE0EB1EUL, 0xF57D4F7FEE6ED178UL,
    0x06F067AA72176FBAUL, 0x0A637DC5A2C898A6UL, 0x113F9804BEF90DAEUL, 0x1B710B35131C471BUL,
    0x28DB77F523047D84UL, 0x32CAAB7B40C72493UL, 0x3C9EBE0A15C9BEBCUL, 0x431D67C49C100D4CUL,
    0x4CC5D4BECB3E42B6UL, 0x597F299CFC657E2AUL, 0x5FCB6FAB3AD6FAECUL, 0x6C44198C4A475817UL,
  ]
}
