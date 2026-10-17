///|
/// `load` of a %.ppk file. An SSH2 public armor reuses the ssh-key decoder.
/// A PuTTY private key is accepted when its MAC matches and encryption is `none`.
fn decode_ppk(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = payload_bytes(value, "decode")
  let text = latin_text(bytes)
  if has_prefix(text, "---- BEGIN SSH2 PUBLIC KEY ----") {
    decode_ssh_key(env, value)
  } else {
    match putty_handle(text) {
      Some(cell) => cell
      None => raise EvalError::Caused("no-codec", "ppk")
    }
  }
}

///|
priv struct PuttyKey {
  version : Int
  kind : String
  encryption : String
  comment : String
  public_blob : Array[Int]
  private_blob : Array[Int]
  mac : String
  use_mac : Bool
}

///|
fn putty_handle(text : String) -> @value.Cell? raise EvalError {
  match putty_key(text) {
    None => None
    Some(key) =>
      if key.kind == "ssh-rsa" &&
        key.encryption == "none" &&
        (key.version == 1 || key.version == 2) &&
        mac_matches(key) {
        rsa_from_putty(key)
      } else {
        None
      }
  }
}

///|
fn putty_key(text : String) -> PuttyKey? {
  let lines = putty_lines(text)
  if lines.length() < 5 || !has_prefix(lines[0], "PuTTY-User-Key-File-") {
    None
  } else {
    let version = lines[0][20].to_int() - 48
    match (field_value(lines, "Encryption:"), field_value(lines, "Comment:")) {
      (Some(encryption), Some(comment)) =>
        match
          (
            counted_text(lines, "Public-Lines:"),
            counted_text(lines, "Private-Lines:"),
            mac_field(lines),
          ) {
          (Some(public_text), Some(private_text), Some(mac)) =>
            Some({
              version,
              kind: after_colon(lines[0]),
              encryption,
              comment,
              public_blob: decode_base64(public_text),
              private_blob: decode_base64(private_text),
              mac: mac.0,
              use_mac: mac.1,
            }) catch {
              _ => None
            }
          _ => None
        }
      _ => None
    }
  }
}

///|
fn rsa_from_putty(key : PuttyKey) -> @value.Cell? {
  match ssh_parts(key.public_blob) {
    None => None
    Some(public) =>
      if latin_text(public.0) == "ssh-rsa" {
        match private_chunks(key.private_blob) {
          None => None
          Some(secret) =>
            match
              @value.RsaKey::from_private(
                public.2,
                public.1,
                secret.0,
                secret.1,
                secret.2,
              ) {
              Some(rsa) => Some(@value.Handle(@value.HandleValue::Rsa(rsa)))
              None => None
            }
        }
      } else {
        None
      }
  }
}

///|
fn private_chunks(bytes : Array[Int]) -> (Array[Int], Array[Int], Array[Int])? {
  match ssh_chunk(bytes, 0) {
    None => None
    Some(d) =>
      match ssh_chunk(bytes, d.1) {
        None => None
        Some(p) =>
          match ssh_chunk(bytes, p.1) {
            None => None
            Some(q) => Some((d.0, p.0, q.0))
          }
      }
  }
}

///|
fn mac_matches(key : PuttyKey) -> Bool raise EvalError {
  let material = mac_material(key)
  let phrase = bytes_of("putty-private-key-file-mac-key")
  let mackey = sha1(phrase)
  let digest = if key.use_mac {
    hmac(mackey, material, "sha1")
  } else {
    sha1(material)
  }
  hex_lower(digest) == key.mac.to_lower()
}

///|
fn mac_material(key : PuttyKey) -> Array[Int] {
  if key.version == 1 {
    key.private_blob
  } else {
    let out : Array[Int] = []
    put_counted(out, bytes_of(key.kind))
    put_counted(out, bytes_of(key.encryption))
    put_counted(out, bytes_of(key.comment))
    put_counted(out, key.public_blob)
    put_counted(out, key.private_blob)
    out
  }
}

///|
fn put_counted(out : Array[Int], bytes : Array[Int]) -> Unit {
  let n = bytes.length()
  out.push((n >> 24) & 0xFF)
  out.push((n >> 16) & 0xFF)
  out.push((n >> 8) & 0xFF)
  out.push(n & 0xFF)
  for byte in bytes {
    out.push(byte)
  }
}

///|
fn field_value(lines : Array[String], prefix : String) -> String? {
  let mut found : String? = None
  for line in lines {
    if has_prefix(line, prefix) {
      found = Some(after_colon(line))
    }
  }
  found
}

///|
fn mac_field(lines : Array[String]) -> (String, Bool)? {
  let mut found : (String, Bool)? = None
  for line in lines {
    if has_prefix(line, "Private-MAC:") {
      found = Some((after_colon(line), true))
    } else if has_prefix(line, "Private-Hash:") {
      found = Some((after_colon(line), false))
    }
  }
  found
}

///|
fn counted_text(lines : Array[String], header : String) -> String? {
  let mut at = -1
  for i in 0..<lines.length() {
    if has_prefix(lines[i], header) {
      at = i
    }
  }
  if at < 0 {
    None
  } else {
    let count = decimal_int(after_colon(lines[at]))
    if count < 0 || at + count >= lines.length() {
      None
    } else {
      let mut joined = ""
      for n in 0..<count {
        joined = joined + lines[at + 1 + n]
      }
      Some(joined)
    }
  }
}

///|
fn after_colon(line : String) -> String {
  let mut index = 0
  while index < line.length() && line[index].to_int() != 58 {
    index = index + 1
  }
  if index + 1 >= line.length() {
    ""
  } else {
    trim_spaces(line[index + 1:].to_owned())
  }
}

///|
fn trim_spaces(text : String) -> String {
  let mut start = 0
  let mut end = text.length()
  while start < end && text[start].to_int() == 32 {
    start = start + 1
  }
  while end > start && text[end - 1].to_int() == 32 {
    end = end - 1
  }
  text[start:end].to_owned()
}

///|
fn decimal_int(text : String) -> Int {
  let mut value = 0
  let mut seen = false
  for char in text {
    let code = char.to_int()
    if code >= 48 && code <= 57 {
      value = value * 10 + code - 48
      seen = true
    }
  }
  if seen {
    value
  } else {
    -1
  }
}

///|
fn putty_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < text.length() {
    if text[index].to_int() == 10 {
      let mut end = index
      if end > start && text[end - 1].to_int() == 13 {
        end = end - 1
      }
      lines.push(text[start:end].to_owned())
      start = index + 1
    }
    index = index + 1
  }
  if start < text.length() {
    lines.push(text[start:].to_owned())
  }
  lines
}

///|
fn bytes_of(text : String) -> Array[Int] {
  let out : Array[Int] = []
  for char in text {
    out.push(char.to_int())
  }
  out
}

///|
fn hex_lower(bytes : Array[Int]) -> String {
  let digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let buf = StringBuilder()
  for byte in bytes {
    buf.write_char(digits[byte / 16])
    buf.write_char(digits[byte % 16])
  }
  buf.to_string()
}
