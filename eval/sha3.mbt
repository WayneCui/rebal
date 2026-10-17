///|
/// SHA-3 is Keccak with the `0x06` domain byte. `rate` and `out_len` are in bytes.
fn sha3(bytes : Array[Int], rate : Int, out_len : Int) -> Array[Int] {
  let padded = sha3_pad(bytes, rate)
  let lanes = sha3_lanes()
  let mut offset = 0
  while offset < padded.length() {
    xor_block(lanes, padded, offset, rate)
    keccak_f(lanes)
    offset = offset + rate
  }
  let out : Array[Int] = []
  while out.length() < out_len {
    let mut index = 0
    while index < rate && out.length() < out_len {
      let lane = lanes[index / 8]
      let shift = index % 8 * 8
      out.push(((lane >> shift) & 0xFFUL).to_int())
      index = index + 1
    }
    if out.length() < out_len {
      keccak_f(lanes)
    }
  }
  out
}

///|
fn sha3_of(name : String, bytes : Array[Int]) -> Array[Int]? {
  match name {
    "sha3-224" => Some(sha3(bytes, 144, 28))
    "sha3-256" => Some(sha3(bytes, 136, 32))
    "sha3-384" => Some(sha3(bytes, 104, 48))
    "sha3-512" => Some(sha3(bytes, 72, 64))
    _ => None
  }
}

///|
fn sha3_pad(bytes : Array[Int], rate : Int) -> Array[Int] {
  let out : Array[Int] = []
  for byte in bytes {
    out.push(byte)
  }
  let gap = rate - bytes.length() % rate
  if gap == 1 {
    out.push(0x86)
  } else {
    out.push(0x06)
    for _ in 0..<(gap - 2) {
      out.push(0)
    }
    out.push(0x80)
  }
  out
}

///|
fn sha3_lanes() -> Array[UInt64] {
  let lanes : Array[UInt64] = []
  for _ in 0..<25 {
    lanes.push(0UL)
  }
  lanes
}

///|
fn xor_block(
  lanes : Array[UInt64],
  bytes : Array[Int],
  offset : Int,
  rate : Int,
) -> Unit {
  for index in 0..<rate {
    let lane = index / 8
    let shift = index % 8 * 8
    lanes[lane] = lanes[lane] ^ (bytes[offset + index].to_uint64() << shift)
  }
}

///|
fn keccak_f(lanes : Array[UInt64]) -> Unit {
  let rounds = sha3_rounds()
  let rots = sha3_rots()
  for round in 0..<24 {
    let column : Array[UInt64] = []
    for x in 0..<5 {
      column.push(
        lanes[x] ^ lanes[x + 5] ^ lanes[x + 10] ^ lanes[x + 15] ^ lanes[x + 20],
      )
    }
    let mixed : Array[UInt64] = []
    for x in 0..<5 {
      mixed.push(column[(x + 4) % 5] ^ rotl64(column[(x + 1) % 5], 1))
    }
    for index in 0..<25 {
      lanes[index] = lanes[index] ^ mixed[index % 5]
    }
    let turned = sha3_lanes()
    for x in 0..<5 {
      for y in 0..<5 {
        let from = x + 5 * y
        let into = y + 5 * ((2 * x + 3 * y) % 5)
        turned[into] = rotl64(lanes[from], rots[from])
      }
    }
    for y in 0..<5 {
      for x in 0..<5 {
        let index = x + 5 * y
        let next = turned[(x + 1) % 5 + 5 * y].lnot()
        let after = turned[(x + 2) % 5 + 5 * y]
        lanes[index] = turned[index] ^ (next & after)
      }
    }
    lanes[0] = lanes[0] ^ rounds[round]
  }
}

///|
fn rotl64(value : UInt64, bits : Int) -> UInt64 {
  if bits == 0 {
    value
  } else {
    (value << bits) | (value >> (64 - bits))
  }
}

///|
fn sha3_rounds() -> Array[UInt64] {
  [
    0x0000000000000001UL, 0x0000000000008082UL, 0x800000000000808AUL, 0x8000000080008000UL,
    0x000000000000808BUL, 0x0000000080000001UL, 0x8000000080008081UL, 0x8000000000008009UL,
    0x000000000000008AUL, 0x0000000000000088UL, 0x0000000080008009UL, 0x000000008000000AUL,
    0x000000008000808BUL, 0x800000000000008BUL, 0x8000000000008089UL, 0x8000000000008003UL,
    0x8000000000008002UL, 0x8000000000000080UL, 0x000000000000800AUL, 0x800000008000000AUL,
    0x8000000080008081UL, 0x8000000000008080UL, 0x0000000080000001UL, 0x8000000080008008UL,
  ]
}

///|
fn sha3_rots() -> Array[Int] {
  [
    0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18,
    2, 61, 56, 14,
  ]
}
