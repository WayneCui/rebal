///|
/// `decode 'ssh-key`. An `ssh-rsa` blob becomes `#(handle! rsa)`.
/// Anything else is the codec dispatcher's `no-codec` error: the Rebol
/// decoder returns `none`, and `decode` turns that into an error.
fn decode_ssh_key(value : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = payload_bytes(value, "decode")
  match read_pem(latin_text(bytes)) {
    Some(pem) =>
      if pem.label == "SSH2 PUBLIC KEY" {
        rsa_handle(pem.bytes)
      } else {
        raise EvalError::Caused("no-codec", "ssh-key")
      }
    None => rsa_handle(ssh_payload(bytes))
  }
}

///|
fn ssh_payload(bytes : Array[Int]) -> Array[Int] raise EvalError {
  let text = latin_text(bytes)
  if has_prefix(text, "ssh-rsa ") {
    let mut end = 8
    while end < text.length() && text[end].to_int() != 32 {
      end = end + 1
    }
    decode_base64(text[8:end].to_owned()) catch {
      _ => raise EvalError::Caused("no-codec", "ssh-key")
    }
  } else {
    bytes
  }
}

///|
fn rsa_handle(bytes : Array[Int]) -> @value.Cell raise EvalError {
  match ssh_parts(bytes) {
    Some(parts) =>
      if latin_text(parts.0) == "ssh-rsa" {
        match @value.RsaKey::new(parts.2, parts.1) {
          Some(key) => @value.Handle(key)
          None => raise EvalError::Caused("no-codec", "ssh-key")
        }
      } else {
        raise EvalError::Caused("no-codec", "ssh-key")
      }
    None => raise EvalError::Caused("no-codec", "ssh-key")
  }
}

///|
/// Three SSH strings: the kind, the exponent, then the modulus.
fn ssh_parts(bytes : Array[Int]) -> (Array[Int], Array[Int], Array[Int])? {
  match ssh_chunk(bytes, 0) {
    None => None
    Some(kind) =>
      match ssh_chunk(bytes, kind.1) {
        None => None
        Some(exponent) =>
          match ssh_chunk(bytes, exponent.1) {
            None => None
            Some(modulus) => Some((kind.0, exponent.0, modulus.0))
          }
      }
  }
}

///|
fn ssh_chunk(bytes : Array[Int], at : Int) -> (Array[Int], Int)? {
  if at + 4 > bytes.length() {
    None
  } else {
    let size = (bytes[at].to_int64() << 24) +
      (bytes[at + 1].to_int64() << 16) +
      (bytes[at + 2].to_int64() << 8) +
      bytes[at + 3].to_int64()
    let next = at + 4
    if size < 0 || size > 1000000 || next + size.to_int() > bytes.length() {
      None
    } else {
      let out : Array[Int] = []
      let mut index = 0
      let count = size.to_int()
      while index < count {
        out.push(bytes[next + index])
        index = index + 1
      }
      Some((out, next + count))
    }
  }
}

///|
fn has_prefix(text : String, prefix : String) -> Bool {
  if text.length() < prefix.length() {
    false
  } else {
    let mut index = 0
    let mut same = true
    while same && index < prefix.length() {
      if text[index] != prefix[index] {
        same = false
      }
      index = index + 1
    }
    same
  }
}
