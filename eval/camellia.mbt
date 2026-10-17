///|
/// Camellia-128, RFC 3713. Eighteen Feistel rounds, FL every six.
priv struct CamelliaBoxes {
  s1 : Array[Int]
  s2 : Array[Int]
  s3 : Array[Int]
}

///|
fn camellia_sbox_text() -> String {
  "70822cecb327c0e5e4855735ea0cae4123ef6b934519a521ed0e4f4e1d6592bd86b8af8f7ceb1fce3e30dc5f5ec50b1aa6e139cad5475d3dd9015ad651566c4d8b0d9a66fbccb02d74122b20f0b18499df4ccbc2347e76056db7a931d11704d714583a61de1b111c320f9c165318f222fe44cfb2c3b57a912408e8a860fc6950aad0a07da1896297545b1e95e0ff64d210c40048a3f775db8a03e6da093fdd94875c8302cd4a90337367f6f39d7fbfe2529bd826c837c63b81966f4b13be632ee979a78c9f6ebc8e29f5f9b62ffdb4597898066ae74671bad425ab4288a28dfa7207b955f8eeac0a36492a683c38f1a44028d37bbbc943c115e3adf477c7809e"
}

///|
fn camellia_boxes() -> CamelliaBoxes {
  let s1 = table_bytes(camellia_sbox_text())
  if s1.length() != 256 || s1[0x3D] != 86 {
    abort("camellia sbox")
  }
  { s1, s2: camellia_rotate(s1, 1), s3: camellia_rotate(s1, 7), }
}

///|
fn camellia_rotate(source : Array[Int], bits : Int) -> Array[Int] {
  let out : Array[Int] = []
  for value in source {
    out.push(rotl8(value, bits))
  }
  out
}

///|
let camellia_box : CamelliaBoxes = camellia_boxes()

///|
fn camellia128_subkeys(key : Array[Int]) -> Array[UInt64] {
  let kl_high = load64(key, 0)
  let kl_low = load64(key, 8)
  let (ka_high, ka_low) = camellia_ka(kl_high, kl_low)
  let keys : Array[UInt64] = []
  keys.push(kl_high)
  keys.push(kl_low)
  keys.push(ka_high)
  keys.push(ka_low)
  push_rot(keys, kl_high, kl_low, 15)
  push_rot(keys, ka_high, ka_low, 15)
  push_rot(keys, ka_high, ka_low, 30)
  push_rot(keys, kl_high, kl_low, 45)
  let (ka45_high, _) = rotl128(ka_high, ka_low, 45)
  keys.push(ka45_high)
  let (_, kl60_low) = rotl128(kl_high, kl_low, 60)
  keys.push(kl60_low)
  push_rot(keys, ka_high, ka_low, 60)
  push_rot(keys, kl_high, kl_low, 77)
  push_rot(keys, kl_high, kl_low, 94)
  push_rot(keys, ka_high, ka_low, 94)
  push_rot(keys, kl_high, kl_low, 111)
  push_rot(keys, ka_high, ka_low, 111)
  keys
}

///|
/// Decryption is encryption with the subkeys reversed, per RFC 3713.
fn camellia128_decrypt_keys(enc : Array[UInt64]) -> Array[UInt64] {
  let dec : Array[UInt64] = []
  for sub in enc {
    dec.push(sub)
  }
  swap_key(dec, 0, 24)
  swap_key(dec, 1, 25)
  swap_key(dec, 2, 23)
  swap_key(dec, 3, 22)
  swap_key(dec, 4, 21)
  swap_key(dec, 5, 20)
  swap_key(dec, 6, 19)
  swap_key(dec, 7, 18)
  swap_key(dec, 8, 17)
  swap_key(dec, 9, 16)
  swap_key(dec, 10, 15)
  swap_key(dec, 11, 14)
  swap_key(dec, 12, 13)
  dec
}

///|
fn camellia128_crypt(keys : Array[UInt64], block : Array[Int]) -> Array[Int] {
  let mut left = load64(block, 0) ^ keys[0]
  let mut right = load64(block, 8) ^ keys[1]
  let first = feistel6(left, right, keys, 2)
  left = camellia_fl(first.0, keys[8])
  right = camellia_flinv(first.1, keys[9])
  let second = feistel6(left, right, keys, 10)
  left = camellia_fl(second.0, keys[16])
  right = camellia_flinv(second.1, keys[17])
  let third = feistel6(left, right, keys, 18)
  let out : Array[Int] = []
  store64(out, third.1 ^ keys[24])
  store64(out, third.0 ^ keys[25])
  out
}

///|
fn camellia_ka(kl_high : UInt64, kl_low : UInt64) -> (UInt64, UInt64) {
  let mut left = kl_high
  let mut right = kl_low
  right = right ^ camellia_f(left, 0xA09E667F3BCC908BUL)
  left = left ^ camellia_f(right, 0xB67AE8584CAA73B2UL)
  left = left ^ kl_high
  right = right ^ kl_low
  right = right ^ camellia_f(left, 0xC6EF372FE94F82BEUL)
  left = left ^ camellia_f(right, 0x54FF53A5F1D36F1CUL)
  (left, right)
}

///|
fn feistel6(
  left : UInt64,
  right : UInt64,
  keys : Array[UInt64],
  at : Int,
) -> (UInt64, UInt64) {
  let mut high = left
  let mut low = right
  let mut cursor = at
  for _ in 0..<3 {
    low = low ^ camellia_f(high, keys[cursor])
    high = high ^ camellia_f(low, keys[cursor + 1])
    cursor = cursor + 2
  }
  (high, low)
}

///|
fn camellia_f(data : UInt64, key : UInt64) -> UInt64 {
  let mixed = data ^ key
  let t1 = camellia_box.s1[octet(mixed, 56)]
  let t2 = camellia_box.s2[octet(mixed, 48)]
  let t3 = camellia_box.s3[octet(mixed, 40)]
  let t4 = camellia_box.s1[rotl8(octet(mixed, 32), 1)]
  let t5 = camellia_box.s2[octet(mixed, 24)]
  let t6 = camellia_box.s3[octet(mixed, 16)]
  let t7 = camellia_box.s1[rotl8(octet(mixed, 8), 1)]
  let t8 = camellia_box.s1[octet(mixed, 0)]
  pack8(
    t1 ^ t3 ^ t4 ^ t6 ^ t7 ^ t8,
    t1 ^ t2 ^ t4 ^ t5 ^ t7 ^ t8,
    t1 ^ t2 ^ t3 ^ t5 ^ t6 ^ t8,
    t2 ^ t3 ^ t4 ^ t5 ^ t6 ^ t7,
    t1 ^ t2 ^ t6 ^ t7 ^ t8,
    t2 ^ t3 ^ t5 ^ t7 ^ t8,
    t3 ^ t4 ^ t5 ^ t6 ^ t8,
    t1 ^ t4 ^ t5 ^ t6 ^ t7,
  )
}

///|
fn camellia_fl(data : UInt64, key : UInt64) -> UInt64 {
  let k1 = key >> 32
  let k2 = key & 0xFFFFFFFFUL
  let x1 = data >> 32
  let x2 = (data & 0xFFFFFFFFUL) ^ roll32(x1 & k1, 1)
  let y1 = x1 ^ (x2 | k2)
  (y1 << 32) | x2
}

///|
fn camellia_flinv(data : UInt64, key : UInt64) -> UInt64 {
  let k1 = key >> 32
  let k2 = key & 0xFFFFFFFFUL
  let y2 = data & 0xFFFFFFFFUL
  let y1 = (data >> 32) ^ (y2 | k2)
  let x2 = y2 ^ roll32(y1 & k1, 1)
  (y1 << 32) | x2
}

///|
fn push_rot(
  keys : Array[UInt64],
  high : UInt64,
  low : UInt64,
  bits : Int,
) -> Unit {
  let (left, right) = rotl128(high, low, bits)
  keys.push(left)
  keys.push(right)
}

///|
fn rotl128(high : UInt64, low : UInt64, bits : Int) -> (UInt64, UInt64) {
  if bits == 0 {
    (high, low)
  } else if bits >= 64 {
    rotl128(low, high, bits - 64)
  } else {
    let upper = (high << bits) | (low >> (64 - bits))
    let lower = (low << bits) | (high >> (64 - bits))
    (upper, lower)
  }
}

///|
fn roll32(value : UInt64, bits : Int) -> UInt64 {
  let low = value & 0xFFFFFFFFUL
  ((low << bits) | (low >> (32 - bits))) & 0xFFFFFFFFUL
}

///|
fn rotl8(value : Int, bits : Int) -> Int {
  let low = value & 255
  ((low << bits) | (low >> (8 - bits))) & 255
}

///|
fn octet(value : UInt64, shift : Int) -> Int {
  ((value >> shift) & 255UL).to_int()
}

///|
fn pack8(
  y1 : Int,
  y2 : Int,
  y3 : Int,
  y4 : Int,
  y5 : Int,
  y6 : Int,
  y7 : Int,
  y8 : Int,
) -> UInt64 {
  let mut out = 0UL
  out = (out << 8) | y1.to_uint64()
  out = (out << 8) | y2.to_uint64()
  out = (out << 8) | y3.to_uint64()
  out = (out << 8) | y4.to_uint64()
  out = (out << 8) | y5.to_uint64()
  out = (out << 8) | y6.to_uint64()
  out = (out << 8) | y7.to_uint64()
  out = (out << 8) | y8.to_uint64()
  out
}

///|
fn load64(block : Array[Int], at : Int) -> UInt64 {
  let mut value = 0UL
  for index in 0..<8 {
    value = (value << 8) | block[at + index].to_uint64()
  }
  value
}

///|
fn store64(out : Array[Int], value : UInt64) -> Unit {
  let mut shift = 56
  while shift >= 0 {
    out.push(((value >> shift) & 255UL).to_int())
    shift = shift - 8
  }
}

///|
fn swap_key(keys : Array[UInt64], left : Int, right : Int) -> Unit {
  let held = keys[left]
  keys[left] = keys[right]
  keys[right] = held
}
