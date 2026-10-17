///|
/// RFC 7468 textual PKIX. `/binary` returns the DER bytes.
/// The block form keeps the label, header fields, and the text around the armor.
fn perform_decode(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut binary = false
  for sym in active {
    if env.symbols.canon(sym) == "binary" {
      binary = true
    } else {
      raise EvalError::Cannot("decode")
    }
  }
  let kind = match args[0] {
    @value.Sym(_, lexeme) => env.symbols.canon(lexeme.sym())
    _ => raise EvalError::Cannot("decode")
  }
  if kind != "pkix" {
    raise EvalError::Cannot("access")
  }
  let text = latin_text(payload_bytes(args[1], "decode"))
  match read_pem(text) {
    Some(pem) =>
      if binary {
        binary_cell(pem.bytes)
      } else {
        pem_block(env, pem)
      }
    None => @value.None
  }
}

///|
priv struct PemText {
  label : String
  bytes : Array[Int]
  tags : Array[String]
  vals : Array[String]
  pre : String
  post : String
}

///|
fn read_pem(text : String) -> PemText? raise EvalError {
  let mut at = 0
  let mut start = -1
  let mut raw = ""
  let mut body = 0
  while at < text.length() && start < 0 {
    match try_begin(text, at) {
      Some(found) => {
        start = at
        raw = found.0
        body = found.1
      }
      None => at = at + 1
    }
  }
  if start < 0 {
    return None
  }
  let tags : Array[String] = []
  let vals : Array[String] = []
  let buf = StringBuilder()
  let mut locked = false
  let mut found_end = false
  let mut post = ""
  let mut cursor = body
  while cursor < text.length() && !found_end {
    let lined = next_line(text, cursor)
    let line = lined.0
    let next = lined.1
    if next <= cursor {
      break
    }
    if end_line(line, raw) {
      post = trim_text(text[next:text.length()].to_owned())
      found_end = true
    } else if !locked {
      match take_header(text, line, next) {
        Some(header) => {
          tags.push(header.0)
          vals.push(header.1)
          cursor = header.2
        }
        None => {
          if line.length() > 0 {
            locked = true
            buf.write_string(line)
          }
          cursor = next
        }
      }
    } else {
      if line.length() > 0 {
        buf.write_string(line)
      }
      cursor = next
    }
  }
  if !found_end {
    None
  } else {
    Some({
      label: trim_tail(raw),
      bytes: decode_base64(buf.to_string()),
      tags,
      vals,
      pre: trim_text(text[0:start].to_owned()),
      post,
    })
  }
}

///|
fn pem_block(env : Env, pem : PemText) -> @value.Cell {
  let block = @value.Series::block()
  block.push_item(set_word_cell(env, "label")) |> ignore
  block.push_item(text_series(pem.label)) |> ignore
  block.push_item(set_word_cell(env, "binary")) |> ignore
  block.push_item(binary_cell(pem.bytes)) |> ignore
  block.push_item(set_word_cell(env, "header")) |> ignore
  block.push_item(pem_header(pem)) |> ignore
  block.push_item(set_word_cell(env, "pre-text")) |> ignore
  block.push_item(text_series(pem.pre)) |> ignore
  block.push_item(set_word_cell(env, "post-text")) |> ignore
  block.push_item(text_series(pem.post)) |> ignore
  @value.Seq(block, 0)
}

///|
fn pem_header(pem : PemText) -> @value.Cell {
  let block = @value.Series::block()
  let mut index = 0
  while index < pem.tags.length() {
    block.push_item(text_series(pem.tags[index])) |> ignore
    block.push_item(text_series(pem.vals[index])) |> ignore
    index = index + 1
  }
  @value.Seq(block, 0)
}

///|
fn set_word_cell(env : Env, spelling : String) -> @value.Cell {
  let folded = spelling.to_lower()
  let sym = env.symbols.intern(folded)
  @value.Sym(@value.SetWord, @value.Lexeme::make(sym, folded))
}

///|
fn try_begin(text : String, at : Int) -> (String, Int)? {
  let five = pem_starts(text, at, "-----BEGIN ")
  let four = pem_starts(text, at, "---- BEGIN ")
  if !five && !four {
    None
  } else {
    let from = at + 11
    let mut index = from
    while index < text.length() && label_char(text[index]) {
      index = index + 1
    }
    let raw = text[from:index].to_owned()
    let close = if five { "-----" } else { "----" }
    if pem_starts(text, index, close) {
      match line_end(text, index + close.length()) {
        Some(next) => Some((raw, next))
        None => None
      }
    } else {
      None
    }
  }
}

///|
fn end_line(line : String, raw : String) -> Bool {
  line == "-----END " + raw + "-----" || line == "---- END " + raw + "----"
}

///|
fn take_header(
  text : String,
  line : String,
  after : Int,
) -> (String, String, Int)? {
  match split_colon(line) {
    None => None
    Some(parts) => {
      let joined = continue_value(text, parts.1, after)
      Some((parts.0, unquote(joined.0), joined.1))
    }
  }
}

///|
fn continue_value(text : String, value : String, cursor : Int) -> (String, Int) {
  let mut acc = value
  let mut at = cursor
  while ends_slash(acc) && at < text.length() {
    acc = acc[0:acc.length() - 1].to_owned()
    let lined = next_line(text, at)
    if lined.1 <= at {
      break
    }
    acc = acc + lined.0
    at = lined.1
  }
  (acc, at)
}

///|
fn split_colon(line : String) -> (String, String)? {
  let mut colon = -1
  let mut index = 0
  while index < line.length() && colon < 0 {
    if line[index].to_int() == 58 {
      colon = index
    }
    index = index + 1
  }
  if colon <= 0 {
    None
  } else {
    let mut ok = true
    let mut cursor = 0
    while cursor < colon {
      let code = line[cursor].to_int()
      if code < 32 || code > 126 {
        ok = false
      }
      cursor = cursor + 1
    }
    if ok {
      Some((line[0:colon].to_owned(), line[colon + 1:line.length()].to_owned()))
    } else {
      None
    }
  }
}

///|
fn next_line(text : String, at : Int) -> (String, Int) {
  let mut index = at
  while index < text.length() &&
        text[index].to_int() != 10 &&
        text[index].to_int() != 13 {
    index = index + 1
  }
  let line = text[at:index].to_owned()
  let next = match line_end(text, index) {
    Some(found) => found
    None => index
  }
  (line, next)
}

///|
fn line_end(text : String, at : Int) -> Int? {
  let len = text.length()
  if at >= len {
    Some(at)
  } else if text[at].to_int() == 10 {
    Some(at + 1)
  } else if text[at].to_int() == 13 {
    if at + 1 < len && text[at + 1].to_int() == 10 {
      Some(at + 2)
    } else {
      Some(at + 1)
    }
  } else {
    None
  }
}

///|
fn pem_starts(text : String, at : Int, prefix : String) -> Bool {
  if at + prefix.length() > text.length() {
    false
  } else {
    let mut index = 0
    let mut same = true
    while index < prefix.length() {
      if text[at + index] != prefix[index] {
        same = false
      }
      index = index + 1
    }
    same
  }
}

///|
fn label_char(unit : UInt16) -> Bool {
  let code = unit.to_int()
  code == 32 || (code >= 0x21 && code <= 0x7E && code != 0x2D)
}

///|
fn ends_slash(text : String) -> Bool {
  text.length() > 0 && text[text.length() - 1].to_int() == 92
}

///|
fn trim_text(text : String) -> String {
  let mut start = 0
  let mut end = text.length()
  while start < end && pem_space(text[start]) {
    start = start + 1
  }
  while end > start && pem_space(text[end - 1]) {
    end = end - 1
  }
  text[start:end].to_owned()
}

///|
fn trim_tail(text : String) -> String {
  let mut end = text.length()
  while end > 0 {
    let code = text[end - 1].to_int()
    if code == 32 || code == 9 {
      end = end - 1
    } else {
      break
    }
  }
  text[0:end].to_owned()
}

///|
fn pem_space(unit : UInt16) -> Bool {
  let code = unit.to_int()
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn unquote(text : String) -> String {
  let trimmed = trim_text(text)
  if trimmed.length() >= 2 &&
    trimmed[0].to_int() == 34 &&
    trimmed[trimmed.length() - 1].to_int() == 34 {
    trimmed[1:trimmed.length() - 1].to_owned()
  } else {
    trimmed
  }
}
