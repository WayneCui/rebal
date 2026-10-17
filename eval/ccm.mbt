///|
/// AES-CCM. A zero tag is CCM*: ciphertext only, counter starting at 1.
fn ccm_message(
  rounds : Array[Int],
  iv : Array[Int],
  aad : Array[Int],
  data : Array[Int],
  tag_len : Int,
  encrypting : Bool,
) -> (Array[Int], Array[Int]) raise EvalError {
  if tag_len == 0 {
    (ccm_stream(rounds, iv, data), [])
  } else {
    let q = 15 - iv.length()
    let ctr = ccm_counter(iv, q)
    let y = ccm_first(rounds, iv, q, aad.length(), data.length(), tag_len)
    if aad.length() > 0 {
      ccm_aad(rounds, y, aad)
    }
    let out = ccm_body(rounds, y, ctr, q, data, encrypting)
    (out, ccm_tag(rounds, y, ctr, q, tag_len))
  }
}

///|
fn ccm_stream(
  rounds : Array[Int],
  iv : Array[Int],
  data : Array[Int],
) -> Array[Int] {
  let q = 15 - iv.length()
  let ctr = ccm_counter(iv, q)
  let out : Array[Int] = []
  let mut index = 0
  let mut offset = 0
  while index < data.length() {
    let mut span = 16 - offset
    if span > data.length() - index {
      span = data.length() - index
    }
    let chunk = slice_from(data, index, span)
    for byte in ccm_xor(rounds, ctr, offset, chunk) {
      out.push(byte)
    }
    offset = offset + span
    if offset == 16 {
      offset = 0
      ccm_inc(ctr, q)
    }
    index = index + span
  }
  out
}

///|
fn ccm_counter(iv : Array[Int], q : Int) -> Array[Int] {
  let ctr = zero_block()
  ctr[0] = q - 1
  let mut index = 0
  while index < iv.length() {
    ctr[index + 1] = iv[index]
    index = index + 1
  }
  ctr[15] = 1
  ctr
}

///|
fn ccm_first(
  rounds : Array[Int],
  iv : Array[Int],
  q : Int,
  aad_len : Int,
  plain_len : Int,
  tag_len : Int,
) -> Array[Int] raise EvalError {
  let y = zero_block()
  let adata = if aad_len > 0 { 1 } else { 0 }
  y[0] = (adata << 6) | (((tag_len - 2) / 2) << 3) | (q - 1)
  let mut index = 0
  while index < iv.length() {
    y[index + 1] = iv[index]
    index = index + 1
  }
  let mut length = plain_len
  index = 0
  while index < q {
    y[15 - index] = length & 255
    length = length >> 8
    index = index + 1
  }
  if length != 0 {
    raise EvalError::Cannot("write")
  }
  aes_encrypt(rounds, y)
}

///|
fn ccm_aad(rounds : Array[Int], y : Array[Int], aad : Array[Int]) -> Unit {
  y[0] = y[0] ^ ((aad.length() >> 8) & 255)
  y[1] = y[1] ^ (aad.length() & 255)
  let mut processed = 0
  let mut index = 0
  while index < aad.length() {
    let offset = (processed + 2) % 16
    let mut span = 16 - offset
    if span > aad.length() - index {
      span = aad.length() - index
    }
    let mut cursor = 0
    while cursor < span {
      y[offset + cursor] = y[offset + cursor] ^ aad[index + cursor]
      cursor = cursor + 1
    }
    processed = processed + span
    index = index + span
    if span + offset == 16 || processed == aad.length() {
      put_block(y, aes_encrypt(rounds, y))
    }
  }
}

///|
fn ccm_body(
  rounds : Array[Int],
  y : Array[Int],
  ctr : Array[Int],
  q : Int,
  data : Array[Int],
  encrypting : Bool,
) -> Array[Int] {
  let out : Array[Int] = []
  let total = data.length()
  let mut processed = 0
  let mut index = 0
  while index < total {
    let offset = processed % 16
    let mut span = 16 - offset
    if span > total - index {
      span = total - index
    }
    let chunk = slice_from(data, index, span)
    processed = processed + span
    if encrypting {
      xor_at(y, offset, chunk)
      if span + offset == 16 || processed == total {
        put_block(y, aes_encrypt(rounds, y))
      }
      for byte in ccm_xor(rounds, ctr, offset, chunk) {
        out.push(byte)
      }
    } else {
      let plain = ccm_xor(rounds, ctr, offset, chunk)
      xor_at(y, offset, plain)
      for byte in plain {
        out.push(byte)
      }
      if span + offset == 16 || processed == total {
        put_block(y, aes_encrypt(rounds, y))
      }
    }
    if span + offset == 16 || processed == total {
      ccm_inc(ctr, q)
    }
    index = index + span
  }
  out
}

///|
fn ccm_tag(
  rounds : Array[Int],
  y : Array[Int],
  ctr : Array[Int],
  q : Int,
  tag_len : Int,
) -> Array[Int] {
  let mut index = 0
  while index < q {
    ctr[15 - index] = 0
    index = index + 1
  }
  let masked = ccm_xor(rounds, ctr, 0, y)
  let tag : Array[Int] = []
  index = 0
  while index < tag_len {
    tag.push(masked[index])
    index = index + 1
  }
  tag
}

///|
fn ccm_xor(
  rounds : Array[Int],
  ctr : Array[Int],
  offset : Int,
  data : Array[Int],
) -> Array[Int] {
  let stream = aes_encrypt(rounds, ctr)
  let out : Array[Int] = []
  let mut index = 0
  while index < data.length() {
    out.push(data[index] ^ stream[offset + index])
    index = index + 1
  }
  out
}

///|
fn ccm_inc(ctr : Array[Int], q : Int) -> Unit {
  let mut index = 0
  while index < q {
    ctr[15 - index] = (ctr[15 - index] + 1) & 255
    if ctr[15 - index] != 0 {
      return
    }
    index = index + 1
  }
}

///|
fn xor_at(block : Array[Int], offset : Int, data : Array[Int]) -> Unit {
  let mut index = 0
  while index < data.length() {
    block[offset + index] = block[offset + index] ^ data[index]
    index = index + 1
  }
}

///|
fn put_block(dst : Array[Int], src : Array[Int]) -> Unit {
  let mut index = 0
  while index < 16 {
    dst[index] = src[index]
    index = index + 1
  }
}

///|
fn zero_block() -> Array[Int] {
  let block : Array[Int] = []
  let mut index = 0
  while index < 16 {
    block.push(0)
    index = index + 1
  }
  block
}

///|
fn slice_from(bytes : Array[Int], at : Int, count : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index < count {
    out.push(bytes[at + index])
    index = index + 1
  }
  out
}
