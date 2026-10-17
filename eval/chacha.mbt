///|
/// IETF ChaCha20. The counter is a 32-bit block index; the nonce is 12 bytes.
fn chacha20_block(
  key : Array[Int],
  counter : UInt64,
  nonce : Array[Int],
) -> Array[Int] {
  let state : Array[UInt64] = [
    0x61707865UL, 0x3320646EUL, 0x79622D32UL, 0x6B206574UL,
  ]
  for index in 0..<8 {
    state.push(le32(key, index * 4))
  }
  state.push(counter & 0xFFFFFFFFUL)
  for index in 0..<3 {
    state.push(le32(nonce, index * 4))
  }
  let original : Array[UInt64] = []
  for word in state {
    original.push(word)
  }
  for _ in 0..<10 {
    chacha_quarter(state, 0, 4, 8, 12)
    chacha_quarter(state, 1, 5, 9, 13)
    chacha_quarter(state, 2, 6, 10, 14)
    chacha_quarter(state, 3, 7, 11, 15)
    chacha_quarter(state, 0, 5, 10, 15)
    chacha_quarter(state, 1, 6, 11, 12)
    chacha_quarter(state, 2, 7, 8, 13)
    chacha_quarter(state, 3, 4, 9, 14)
  }
  let out : Array[Int] = []
  for index in 0..<16 {
    push_le(out, chacha_add(state[index], original[index]))
  }
  out
}

///|
fn chacha_quarter(
  state : Array[UInt64],
  a : Int,
  b : Int,
  c : Int,
  d : Int,
) -> Unit {
  state[a] = chacha_add(state[a], state[b])
  state[d] = chacha_rotl(state[d] ^ state[a], 16)
  state[c] = chacha_add(state[c], state[d])
  state[b] = chacha_rotl(state[b] ^ state[c], 12)
  state[a] = chacha_add(state[a], state[b])
  state[d] = chacha_rotl(state[d] ^ state[a], 8)
  state[c] = chacha_add(state[c], state[d])
  state[b] = chacha_rotl(state[b] ^ state[c], 7)
}

///|
fn chacha_add(left : UInt64, right : UInt64) -> UInt64 {
  (left + right) & 0xFFFFFFFFUL
}

///|
fn chacha_rotl(value : UInt64, bits : Int) -> UInt64 {
  let low = value & 0xFFFFFFFFUL
  ((low << bits) | (low >> (32 - bits))) & 0xFFFFFFFFUL
}

///|
fn le32(bytes : Array[Int], at : Int) -> UInt64 {
  bytes[at].to_uint64() |
  (bytes[at + 1].to_uint64() << 8) |
  (bytes[at + 2].to_uint64() << 16) |
  (bytes[at + 3].to_uint64() << 24)
}

///|
fn push_le(out : Array[Int], word : UInt64) -> Unit {
  let value = word & 0xFFFFFFFFUL
  out.push((value & 255UL).to_int())
  out.push(((value >> 8) & 255UL).to_int())
  out.push(((value >> 16) & 255UL).to_int())
  out.push(((value >> 24) & 255UL).to_int())
}

///|
fn be32(bytes : Array[Int], at : Int) -> UInt64 {
  (bytes[at].to_uint64() << 24) |
  (bytes[at + 1].to_uint64() << 16) |
  (bytes[at + 2].to_uint64() << 8) |
  bytes[at + 3].to_uint64()
}
