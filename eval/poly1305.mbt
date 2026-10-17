///|
let poly_mask : UInt64 = 0x3FFFFFFUL

///|
priv struct PolyR {
  r0 : UInt64
  r1 : UInt64
  r2 : UInt64
  r3 : UInt64
  r4 : UInt64
  s1 : UInt64
  s2 : UInt64
  s3 : UInt64
  s4 : UInt64
}

///|
/// Poly1305 tag over `msg` with a 32-byte one-time key.
fn poly1305(key : Array[Int], msg : Array[Int]) -> Array[Int] {
  let factor = poly_r(key)
  let h : Array[UInt64] = [0UL, 0UL, 0UL, 0UL, 0UL]
  let mut offset = 0
  while offset < msg.length() {
    let remain = msg.length() - offset
    let take = if remain > 16 { 16 } else { remain }
    let block : Array[Int] = []
    let mut index = 0
    while index < 16 {
      block.push(0)
      index = index + 1
    }
    index = 0
    while index < take {
      block[index] = msg[offset + index]
      index = index + 1
    }
    let hibit = if take == 16 { 1UL } else { 0UL }
    if take < 16 {
      block[take] = 1
    }
    poly_block(h, factor, block, hibit)
    offset = offset + take
  }
  poly_bytes(h, key)
}

///|
/// AEAD tag. The one-time key is the first 32 bytes of ChaCha20 block 0.
fn poly1305_tag(
  key : Array[Int],
  nonce : Array[Int],
  aad : Array[Int],
  cipher : Array[Int],
) -> Array[Int] {
  let stream = chacha20_block(key, 0UL, nonce)
  let once : Array[Int] = []
  let mut index = 0
  while index < 32 {
    once.push(stream[index])
    index = index + 1
  }
  poly1305(once, poly_message(aad, cipher))
}

///|
fn poly_message(aad : Array[Int], cipher : Array[Int]) -> Array[Int] {
  let msg : Array[Int] = []
  for byte in aad {
    msg.push(byte)
  }
  poly_pad(msg, aad.length())
  for byte in cipher {
    msg.push(byte)
  }
  poly_pad(msg, cipher.length())
  poly_le64(msg, aad.length())
  poly_le64(msg, cipher.length())
  msg
}

///|
fn poly_pad(msg : Array[Int], len : Int) -> Unit {
  let extra = if len % 16 == 0 { 0 } else { 16 - len % 16 }
  let mut index = 0
  while index < extra {
    msg.push(0)
    index = index + 1
  }
}

///|
fn poly_le64(msg : Array[Int], len : Int) -> Unit {
  let mut value = len.to_uint64()
  let mut index = 0
  while index < 8 {
    msg.push((value & 255UL).to_int())
    value = value >> 8
    index = index + 1
  }
}

///|
fn poly_r(key : Array[Int]) -> PolyR {
  let r : Array[Int] = []
  let mut index = 0
  while index < 16 {
    r.push(key[index])
    index = index + 1
  }
  r[3] = r[3] & 15
  r[7] = r[7] & 15
  r[11] = r[11] & 15
  r[15] = r[15] & 15
  r[4] = r[4] & 252
  r[8] = r[8] & 252
  r[12] = r[12] & 252
  let r0 = le32(r, 0) & poly_mask
  let r1 = (le32(r, 3) >> 2) & poly_mask
  let r2 = (le32(r, 6) >> 4) & poly_mask
  let r3 = (le32(r, 9) >> 6) & poly_mask
  let r4 = (le32(r, 12) >> 8) & poly_mask
  {
    r0,
    r1,
    r2,
    r3,
    r4,
    s1: r1 * 5UL,
    s2: r2 * 5UL,
    s3: r3 * 5UL,
    s4: r4 * 5UL,
  }
}

///|
fn poly_block(
  h : Array[UInt64],
  factor : PolyR,
  block : Array[Int],
  hibit : UInt64,
) -> Unit {
  let t0 = le32(block, 0)
  let t1 = le32(block, 4)
  let t2 = le32(block, 8)
  let t3 = le32(block, 12)
  h[0] = h[0] + (t0 & poly_mask)
  h[1] = h[1] + (((t0 >> 26) | (t1 << 6)) & poly_mask)
  h[2] = h[2] + (((t1 >> 20) | (t2 << 12)) & poly_mask)
  h[3] = h[3] + (((t2 >> 14) | (t3 << 18)) & poly_mask)
  h[4] = h[4] + ((t3 >> 8) | (hibit << 24))
  let d0 = h[0] * factor.r0 +
    h[1] * factor.s4 +
    h[2] * factor.s3 +
    h[3] * factor.s2 +
    h[4] * factor.s1
  let mut d1 = h[0] * factor.r1 +
    h[1] * factor.r0 +
    h[2] * factor.s4 +
    h[3] * factor.s3 +
    h[4] * factor.s2
  let mut d2 = h[0] * factor.r2 +
    h[1] * factor.r1 +
    h[2] * factor.r0 +
    h[3] * factor.s4 +
    h[4] * factor.s3
  let mut d3 = h[0] * factor.r3 +
    h[1] * factor.r2 +
    h[2] * factor.r1 +
    h[3] * factor.r0 +
    h[4] * factor.s4
  let mut d4 = h[0] * factor.r4 +
    h[1] * factor.r3 +
    h[2] * factor.r2 +
    h[3] * factor.r1 +
    h[4] * factor.r0
  let mut carry = d0 >> 26
  h[0] = d0 & poly_mask
  d1 = d1 + carry
  carry = d1 >> 26
  h[1] = d1 & poly_mask
  d2 = d2 + carry
  carry = d2 >> 26
  h[2] = d2 & poly_mask
  d3 = d3 + carry
  carry = d3 >> 26
  h[3] = d3 & poly_mask
  d4 = d4 + carry
  carry = d4 >> 26
  h[4] = d4 & poly_mask
  h[0] = h[0] + carry * 5UL
  carry = h[0] >> 26
  h[0] = h[0] & poly_mask
  h[1] = h[1] + carry
}

///|
fn poly_bytes(h : Array[UInt64], key : Array[Int]) -> Array[Int] {
  poly_carry(h)
  let g = poly_minus_p(h)
  let mask = (g[4] >> 63) - 1UL
  let keep = mask.lnot()
  let mut index = 0
  while index < 5 {
    h[index] = (h[index] & keep) | (g[index] & mask)
    index = index + 1
  }
  let w0 = (h[0] | (h[1] << 26)) & 0xFFFFFFFFUL
  let w1 = ((h[1] >> 6) | (h[2] << 20)) & 0xFFFFFFFFUL
  let w2 = ((h[2] >> 12) | (h[3] << 14)) & 0xFFFFFFFFUL
  let w3 = ((h[3] >> 18) | (h[4] << 8)) & 0xFFFFFFFFUL
  let t0 = le32(key, 16)
  let t1 = le32(key, 20)
  let t2 = le32(key, 24)
  let t3 = le32(key, 28)
  let f0 = w0 + t0
  let f1 = w1 + t1 + (f0 >> 32)
  let f2 = w2 + t2 + (f1 >> 32)
  let f3 = w3 + t3 + (f2 >> 32)
  let out : Array[Int] = []
  push_le(out, f0)
  push_le(out, f1)
  push_le(out, f2)
  push_le(out, f3)
  out
}

///|
fn poly_carry(h : Array[UInt64]) -> Unit {
  let mut carry = h[1] >> 26
  h[1] = h[1] & poly_mask
  h[2] = h[2] + carry
  carry = h[2] >> 26
  h[2] = h[2] & poly_mask
  h[3] = h[3] + carry
  carry = h[3] >> 26
  h[3] = h[3] & poly_mask
  h[4] = h[4] + carry
  carry = h[4] >> 26
  h[4] = h[4] & poly_mask
  h[0] = h[0] + carry * 5UL
  carry = h[0] >> 26
  h[0] = h[0] & poly_mask
  h[1] = h[1] + carry
}

///|
fn poly_minus_p(h : Array[UInt64]) -> Array[UInt64] {
  let g : Array[UInt64] = [0UL, 0UL, 0UL, 0UL, 0UL]
  g[0] = h[0] + 5UL
  let mut carry = g[0] >> 26
  g[0] = g[0] & poly_mask
  g[1] = h[1] + carry
  carry = g[1] >> 26
  g[1] = g[1] & poly_mask
  g[2] = h[2] + carry
  carry = g[2] >> 26
  g[2] = g[2] & poly_mask
  g[3] = h[3] + carry
  carry = g[3] >> 26
  g[3] = g[3] & poly_mask
  g[4] = h[4] + carry - (1UL << 26)
  g
}
