///|
priv struct GcmRun {
  mut y : Array[Int]
  mut h : Array[Int]
  mut base : Array[Int]
  mut buf : Array[Int]
  mut alen : Int
  mut clen : Int
  mut phase : Int
  mut done : Bool
  mut blank : Bool
}

///|
fn gcm_new() -> GcmRun {
  {
    y: zero_block(),
    h: zero_block(),
    base: zero_block(),
    buf: zero_block(),
    alen: 0,
    clen: 0,
    phase: 0,
    done: false,
    blank: false,
  }
}

///|
fn gcm_start(
  run : GcmRun,
  rounds : Array[Int],
  iv : Array[Int],
) -> Unit raise EvalError {
  if iv.length() == 0 {
    raise EvalError::Cannot("write")
  }
  run.h = aes_encrypt(rounds, zero_block())
  run.y = gcm_counter(run.h, iv)
  run.base = aes_encrypt(rounds, run.y)
  run.buf = zero_block()
  run.alen = 0
  run.clen = 0
  run.phase = 0
  run.done = false
  run.blank = false
}

///|
fn gcm_counter(h : Array[Int], iv : Array[Int]) -> Array[Int] {
  if iv.length() == 12 {
    let y = zero_block()
    let mut index = 0
    while index < 12 {
      y[index] = iv[index]
      index = index + 1
    }
    y[15] = 1
    y
  } else {
    let data : Array[Int] = []
    for byte in iv {
      data.push(byte)
    }
    while data.length() % 16 != 0 {
      data.push(0)
    }
    let lenb = zero_block()
    put_be64(lenb, 8, iv.length() * 8)
    for byte in lenb {
      data.push(byte)
    }
    ghash_all(h, data)
  }
}

///|
fn ghash_all(h : Array[Int], data : Array[Int]) -> Array[Int] {
  let mut acc = zero_block()
  let mut index = 0
  while index < data.length() {
    let block = zero_block()
    let mut cursor = 0
    while cursor < 16 && index + cursor < data.length() {
      block[cursor] = data[index + cursor]
      cursor = cursor + 1
    }
    xor_at(acc, 0, block)
    acc = gf_mult(acc, h)
    index = index + 16
  }
  acc
}

///|
fn gcm_aad(run : GcmRun, aad : Array[Int]) -> Unit {
  let mut index = 0
  let mut offset = run.alen % 16
  if offset != 0 {
    let mut span = 16 - offset
    if span > aad.length() {
      span = aad.length()
    }
    xor_at(run.buf, offset, slice_from(aad, 0, span))
    if offset + span == 16 {
      run.buf = gf_mult(run.buf, run.h)
    }
    run.alen = run.alen + span
    index = span
    offset = 0
  }
  while index < aad.length() {
    let left = aad.length() - index
    let span = if left > 16 { 16 } else { left }
    xor_at(run.buf, 0, slice_from(aad, index, span))
    run.alen = run.alen + span
    index = index + span
    if span == 16 {
      run.buf = gf_mult(run.buf, run.h)
    }
  }
}

///|
fn gcm_data(
  run : GcmRun,
  rounds : Array[Int],
  data : Array[Int],
  encrypting : Bool,
) -> Array[Int] {
  let out : Array[Int] = []
  if data.length() == 0 {
    return out
  }
  if run.clen == 0 && run.alen % 16 != 0 {
    run.buf = gf_mult(run.buf, run.h)
  }
  let mut index = 0
  let offset = run.clen % 16
  if offset != 0 {
    let mut span = 16 - offset
    if span > data.length() {
      span = data.length()
    }
    let chunk = slice_from(data, 0, span)
    for byte in gcm_mask(run, rounds, offset, chunk, encrypting) {
      out.push(byte)
    }
    if offset + span == 16 {
      run.buf = gf_mult(run.buf, run.h)
    }
    run.clen = run.clen + span
    index = span
  }
  while index < data.length() {
    let left = data.length() - index
    let span = if left > 16 { 16 } else { left }
    gcm_incr(run.y)
    let chunk = slice_from(data, index, span)
    for byte in gcm_mask(run, rounds, 0, chunk, encrypting) {
      out.push(byte)
    }
    run.clen = run.clen + span
    index = index + span
    if span == 16 {
      run.buf = gf_mult(run.buf, run.h)
    }
  }
  out
}

///|
fn gcm_mask(
  run : GcmRun,
  rounds : Array[Int],
  offset : Int,
  chunk : Array[Int],
  encrypting : Bool,
) -> Array[Int] {
  let stream = aes_encrypt(rounds, run.y)
  if !encrypting {
    xor_at(run.buf, offset, chunk)
  }
  let mixed : Array[Int] = []
  let mut index = 0
  while index < chunk.length() {
    mixed.push(chunk[index] ^ stream[offset + index])
    index = index + 1
  }
  if encrypting {
    xor_at(run.buf, offset, mixed)
  }
  mixed
}

///|
fn gcm_tag(run : GcmRun, tag_len : Int) -> Array[Int] {
  if run.clen == 0 && run.alen % 16 != 0 {
    run.buf = gf_mult(run.buf, run.h)
  }
  if run.clen % 16 != 0 {
    run.buf = gf_mult(run.buf, run.h)
  }
  if run.clen != 0 || run.alen != 0 {
    let lenb = zero_block()
    put_be64(lenb, 0, run.alen * 8)
    put_be64(lenb, 8, run.clen * 8)
    xor_at(run.buf, 0, lenb)
    run.buf = gf_mult(run.buf, run.h)
  }
  let tag : Array[Int] = []
  let mut index = 0
  while index < tag_len {
    tag.push(run.base[index] ^ run.buf[index])
    index = index + 1
  }
  tag
}

///|
fn gcm_incr(y : Array[Int]) -> Unit {
  let mut index = 15
  while index >= 12 {
    y[index] = (y[index] + 1) & 255
    if y[index] != 0 {
      return
    }
    index = index - 1
  }
}

///|
fn gf_mult(left : Array[Int], right : Array[Int]) -> Array[Int] {
  let loaded = load128(left)
  let mut vhi = loaded.0
  let mut vlo = loaded.1
  let mut zhi = 0UL
  let mut zlo = 0UL
  let mut index = 0
  while index < 128 {
    if gcm_bit(right, index) {
      zhi = zhi ^ vhi
      zlo = zlo ^ vlo
    }
    let low = vlo & 1UL
    vlo = (vlo >> 1) | ((vhi & 1UL) << 63)
    vhi = vhi >> 1
    if low != 0UL {
      vhi = vhi ^ 0xE100000000000000UL
    }
    index = index + 1
  }
  store128(zhi, zlo)
}

///|
fn gcm_bit(block : Array[Int], index : Int) -> Bool {
  let byte = block[index / 8]
  let shift = 7 - index % 8
  ((byte >> shift) & 1) != 0
}

///|
fn load128(block : Array[Int]) -> (UInt64, UInt64) {
  let mut hi = 0UL
  let mut lo = 0UL
  let mut index = 0
  while index < 8 {
    hi = (hi << 8) | block[index].to_uint64()
    index = index + 1
  }
  while index < 16 {
    lo = (lo << 8) | block[index].to_uint64()
    index = index + 1
  }
  (hi, lo)
}

///|
fn store128(hi : UInt64, lo : UInt64) -> Array[Int] {
  let out : Array[Int] = []
  push_be(out, hi)
  push_be(out, lo)
  out
}

///|
fn push_be(out : Array[Int], value : UInt64) -> Unit {
  let mut shift = 56
  while shift >= 0 {
    out.push(((value >> shift) & 255UL).to_int())
    shift = shift - 8
  }
}

///|
fn put_be64(block : Array[Int], at : Int, value : Int) -> Unit {
  let mut number = value
  let mut index = 7
  while index >= 0 {
    block[at + index] = number & 255
    number = number >> 8
    index = index - 1
  }
}
