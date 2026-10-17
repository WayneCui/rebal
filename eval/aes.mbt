///|
/// AES-128 block cipher. ECB is one block at a time; chaining lives in the port.
priv struct AesTables {
  sbox : Array[Int]
  inv : Array[Int]
}

///|
fn aes_sbox_text() -> String {
  "637c777bf26b6fc53001672bfed7ab76ca82c97dfa5947f0add4a2af9ca472c0b7fd9326363ff7cc34a5e5f171d8311504c723c31896059a071280e2eb27b27509832c1a1b6e5aa0523bd6b329e32f8453d100ed20fcb15b6acbbe394a4c58cfd0efaafb434d338545f9027f503c9fa851a3408f929d38f5bcb6da2110fff3d2cd0c13ec5f974417c4a77e3d645d197360814fdc222a908846eeb814de5e0bdbe0323a0a4906245cc2d3ac629195e479e7c8376d8dd54ea96c56f4ea657aae08ba78252e1ca6b4c6e8dd741f4bbd8b8a703eb5664803f60e613557b986c11d9ee1f8981169d98e949b1e87e9ce5528df8ca1890dbfe6426841992d0fb054bb16"
}

///|
fn aes_inv_text() -> String {
  "52096ad53036a538bf40a39e81f3d7fb7ce339829b2fff87348e4344c4dee9cb547b9432a6c2233dee4c950b42fac34e082ea16628d924b2765ba2496d8bd12572f8f66486689816d4a45ccc5d65b6926c704850fdedb9da5e154657a78d9d8490d8ab008cbcd30af7e45805b8b34506d02c1e8fca3f0f02c1afbd0301138a6b3a9111414f67dcea97f2cfcef0b4e67396ac7422e7ad3585e2f937e81c75df6e47f11a711d29c5896fb7620eaa18be1bfc563e4bc6d279209adbc0fe78cd5af41fdda8338807c731b11210592780ec5f60517fa919b54a0d2de57a9f93c99cefa0e03b4dae2af5b0c8ebbb3c83539961172b047eba77d626e169146355210c7d"
}

///|
fn table_bytes(text : String) -> Array[Int] {
  let bytes : Array[Int] = []
  let mut index = 0
  while index + 1 < text.length() {
    let high = text[index].to_int()
    let low = text[index + 1].to_int()
    bytes.push(hex_nibble(high) * 16 + hex_nibble(low))
    index = index + 2
  }
  bytes
}

///|
fn hex_nibble(code : Int) -> Int {
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 97 && code <= 102 {
    code - 87
  } else {
    0
  }
}

///|
let aes_tables : AesTables = {
  sbox: table_bytes(aes_sbox_text()),
  inv: table_bytes(aes_inv_text()),
}

///|
/// Expands a 16-byte key into the 11 round keys AES-128 applies in order.
fn aes128_rounds(key : Array[Int]) -> Array[Int] raise EvalError {
  if key.length() != 16 {
    raise EvalError::Cannot("modify")
  }
  let rounds : Array[Int] = []
  for byte in key {
    rounds.push(byte)
  }
  let rcon = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]
  let mut word = 4
  while word < 44 {
    let mut t0 = rounds[(word - 1) * 4]
    let mut t1 = rounds[(word - 1) * 4 + 1]
    let mut t2 = rounds[(word - 1) * 4 + 2]
    let mut t3 = rounds[(word - 1) * 4 + 3]
    if word % 4 == 0 {
      let spun = t0
      t0 = aes_tables.sbox[t1] ^ rcon[word / 4 - 1]
      t1 = aes_tables.sbox[t2]
      t2 = aes_tables.sbox[t3]
      t3 = aes_tables.sbox[spun]
    }
    let prev = (word - 4) * 4
    rounds.push(rounds[prev] ^ t0)
    rounds.push(rounds[prev + 1] ^ t1)
    rounds.push(rounds[prev + 2] ^ t2)
    rounds.push(rounds[prev + 3] ^ t3)
    word = word + 1
  }
  rounds
}

///|
fn aes128_encrypt(rounds : Array[Int], block : Array[Int]) -> Array[Int] {
  let state = copy_block(block)
  add_round(state, rounds, 0)
  for round in 1..<10 {
    sub_bytes(state, aes_tables.sbox)
    shift_rows(state)
    mix_columns(state)
    add_round(state, rounds, round)
  }
  sub_bytes(state, aes_tables.sbox)
  shift_rows(state)
  add_round(state, rounds, 10)
  state
}

///|
fn aes128_decrypt(rounds : Array[Int], block : Array[Int]) -> Array[Int] {
  let state = copy_block(block)
  add_round(state, rounds, 10)
  let mut round = 9
  while round >= 1 {
    inv_shift_rows(state)
    sub_bytes(state, aes_tables.inv)
    add_round(state, rounds, round)
    inv_mix_columns(state)
    round = round - 1
  }
  inv_shift_rows(state)
  sub_bytes(state, aes_tables.inv)
  add_round(state, rounds, 0)
  state
}

///|
fn copy_block(block : Array[Int]) -> Array[Int] {
  let state : Array[Int] = []
  for byte in block {
    state.push(byte)
  }
  state
}

///|
fn add_round(state : Array[Int], rounds : Array[Int], round : Int) -> Unit {
  let base = round * 16
  for index in 0..<16 {
    state[index] = state[index] ^ rounds[base + index]
  }
}

///|
fn sub_bytes(state : Array[Int], box : Array[Int]) -> Unit {
  for index in 0..<16 {
    state[index] = box[state[index]]
  }
}

///|
fn shift_rows(state : Array[Int]) -> Unit {
  let first = state[1]
  state[1] = state[5]
  state[5] = state[9]
  state[9] = state[13]
  state[13] = first
  let second = state[2]
  let sixth = state[6]
  state[2] = state[10]
  state[6] = state[14]
  state[10] = second
  state[14] = sixth
  let last = state[15]
  state[15] = state[11]
  state[11] = state[7]
  state[7] = state[3]
  state[3] = last
}

///|
fn inv_shift_rows(state : Array[Int]) -> Unit {
  let first = state[13]
  state[13] = state[9]
  state[9] = state[5]
  state[5] = state[1]
  state[1] = first
  let second = state[2]
  let sixth = state[6]
  state[2] = state[10]
  state[6] = state[14]
  state[10] = second
  state[14] = sixth
  let third = state[3]
  state[3] = state[7]
  state[7] = state[11]
  state[11] = state[15]
  state[15] = third
}

///|
fn mix_columns(state : Array[Int]) -> Unit {
  for column in 0..<4 {
    mix_column(state, column * 4, false)
  }
}

///|
fn inv_mix_columns(state : Array[Int]) -> Unit {
  for column in 0..<4 {
    mix_column(state, column * 4, true)
  }
}

///|
fn mix_column(state : Array[Int], base : Int, inverse : Bool) -> Unit {
  let s0 = state[base]
  let s1 = state[base + 1]
  let s2 = state[base + 2]
  let s3 = state[base + 3]
  if inverse {
    state[base] = gmul(s0, 14) ^ gmul(s1, 11) ^ gmul(s2, 13) ^ gmul(s3, 9)
    state[base + 1] = gmul(s0, 9) ^ gmul(s1, 14) ^ gmul(s2, 11) ^ gmul(s3, 13)
    state[base + 2] = gmul(s0, 13) ^ gmul(s1, 9) ^ gmul(s2, 14) ^ gmul(s3, 11)
    state[base + 3] = gmul(s0, 11) ^ gmul(s1, 13) ^ gmul(s2, 9) ^ gmul(s3, 14)
  } else {
    state[base] = gmul(s0, 2) ^ gmul(s1, 3) ^ s2 ^ s3
    state[base + 1] = s0 ^ gmul(s1, 2) ^ gmul(s2, 3) ^ s3
    state[base + 2] = s0 ^ s1 ^ gmul(s2, 2) ^ gmul(s3, 3)
    state[base + 3] = gmul(s0, 3) ^ s1 ^ s2 ^ gmul(s3, 2)
  }
}

///|
fn gmul(left : Int, right : Int) -> Int {
  let mut product = 0
  let mut value = left
  let mut factor = right
  for _ in 0..<8 {
    if (factor & 1) != 0 {
      product = product ^ value
    }
    let high = value & 128
    value = (value << 1) & 255
    if high != 0 {
      value = value ^ 0x1B
    }
    factor = factor >> 1
  }
  product
}
