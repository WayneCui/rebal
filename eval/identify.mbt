///|
/// `encoding?` names the codec that recognizes a binary.
/// The search follows this build's codec order: zip, gzip, ar, der, pkix.
/// Anything else, including an empty binary, is text.
fn perform_encoding(
  env : Env,
  data : @value.Cell,
) -> @value.Cell raise EvalError {
  match binary_of(data) {
    Some(bytes) => codec_word(env, encoding_name(bytes))
    None => raise EvalError::Caused("expect-arg", "encoding?")
  }
}

///|
fn encoding_name(bytes : Array[Int]) -> String {
  if bytes.length() == 0 {
    "text"
  } else if zip_magic(bytes) {
    "zip"
  } else if gzip_magic(bytes) {
    "gzip"
  } else if ar_magic(bytes) {
    "ar"
  } else if bytes[0] == 48 {
    "der"
  } else if pkix_magic(bytes) {
    "pkix"
  } else {
    "text"
  }
}

///|
fn codec_word(env : Env, name : String) -> @value.Cell {
  @value.Sym(@value.Word, @value.Lexeme::make(env.symbols.intern(name), name))
}

///|
/// Zip's marker is `PK`, and four bytes are not enough.
fn zip_magic(bytes : Array[Int]) -> Bool {
  bytes.length() > 4 && bytes[0] == 80 && bytes[1] == 75
}

///|
/// Gzip needs the ten-byte header and compression method 8.
fn gzip_magic(bytes : Array[Int]) -> Bool {
  bytes.length() >= 10 && bytes[0] == 0x1F && bytes[1] == 0x8B && bytes[2] == 8
}

///|
fn ar_magic(bytes : Array[Int]) -> Bool {
  bytes_match(bytes, 0, "!<arch>\n")
}

///|
/// A PEM label may follow a prefix that contains no dash.
/// The label line must end in a line feed. A carriage return before it is optional.
fn pkix_magic(bytes : Array[Int]) -> Bool {
  let mut index = 0
  while index < bytes.length() && bytes[index] != 45 {
    index = index + 1
  }
  pkix_form(bytes, index, "---- BEGIN ", "----") ||
  pkix_form(bytes, index, "-----BEGIN ", "-----")
}

///|
fn pkix_form(
  bytes : Array[Int],
  at : Int,
  prefix : String,
  closer : String,
) -> Bool {
  if !bytes_match(bytes, at, prefix) {
    false
  } else {
    let mut index = at + prefix.length()
    while index < bytes.length() && encoding_label(bytes[index]) {
      index = index + 1
    }
    if bytes_match(bytes, index, closer) {
      index = index + closer.length()
      if index < bytes.length() && bytes[index] == 13 {
        index = index + 1
      }
      index < bytes.length() && bytes[index] == 10
    } else {
      false
    }
  }
}

///|
/// Printable ASCII, including space, excluding the dash that ends the label.
fn encoding_label(byte : Int) -> Bool {
  byte == 32 || (byte >= 0x21 && byte <= 0x2C) || (byte >= 0x2E && byte <= 0x7E)
}

///|
fn bytes_match(bytes : Array[Int], at : Int, text : String) -> Bool {
  let mut index = 0
  let mut matched = true
  for char in text {
    if at + index >= bytes.length() || bytes[at + index] != char.to_int() {
      matched = false
    }
    index = index + 1
  }
  matched
}
