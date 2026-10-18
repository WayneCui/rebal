///|
/// XML as a block, the shape from codec-xml.reb's block-handler.
/// `[document #[...] [element ...]]`. An element is `[name attributes content]`.
/// A missing attribute list or content list stays none. Text runs through the
/// HTML character references.
fn decode_xml(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      text_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      qp_text(bytes_from(series, index))
    _ => raise EvalError::Cannot("decode")
  }
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  let info = @value.MapValue::make()
  let cursor = xml_prolog(env, codes, info)
  if cursor >= codes.length() || codes[cursor] != '<'.to_int() {
    raise EvalError::Cannot("decode")
  }
  let (root, after) = xml_element(env, codes, cursor)
  if xml_trailer(codes, after) != codes.length() {
    raise EvalError::Cannot("decode")
  }
  let block = @value.Series::block()
  block.push_item(xml_word(env, "document")) |> ignore
  block.push_item(@value.Map(info)) |> ignore
  let kids = @value.Series::block()
  kids.push_item(root) |> ignore
  block.push_item(@value.Seq(kids, 0)) |> ignore
  @value.Seq(block, 0)
}

///|
/// A declaration counts only at the start. A later `<?xml` is an ordinary
/// processing instruction, which is why a leading comment leaves version unset.
fn xml_prolog(
  env : Env,
  codes : Array[Int],
  info : @value.MapValue,
) -> Int raise EvalError {
  let mut cursor = xml_skip(codes, 0)
  if xml_starts(codes, cursor, "<?xml") {
    cursor = xml_declaration(env, codes, cursor + 5, info)
  }
  let mut seen = false
  let mut scanning = true
  while scanning {
    cursor = xml_skip(codes, cursor)
    let (misc, after) = xml_misc(codes, cursor)
    if misc {
      cursor = after
    } else if xml_starts(codes, cursor, "<!DOCTYPE") {
      if seen {
        raise EvalError::Cannot("decode")
      }
      cursor = xml_doctype(env, codes, cursor, info)
      seen = true
    } else {
      scanning = false
    }
  }
  cursor
}

///|
fn xml_trailer(codes : Array[Int], at : Int) -> Int raise EvalError {
  let mut cursor = at
  let mut scanning = true
  while scanning {
    cursor = xml_skip(codes, cursor)
    let (misc, after) = xml_misc(codes, cursor)
    if misc {
      cursor = after
    } else {
      scanning = false
    }
  }
  cursor
}

///|
fn xml_misc(codes : Array[Int], at : Int) -> (Bool, Int) raise EvalError {
  if xml_starts(codes, at, "<!--") {
    (true, xml_find(codes, at + 4, "-->"))
  } else if xml_starts(codes, at, "<?") {
    (true, xml_find(codes, at + 2, "?>"))
  } else {
    (false, at)
  }
}

///|
fn xml_doctype(
  env : Env,
  codes : Array[Int],
  at : Int,
  info : @value.MapValue,
) -> Int raise EvalError {
  let mut cursor = at + 9
  if cursor >= codes.length() || !xml_space(codes[cursor]) {
    raise EvalError::Cannot("decode")
  }
  cursor = xml_skip(codes, cursor)
  let (name, named) = xml_name(codes, cursor)
  info.put(xml_word(env, "doctype"), text_series(name))
  cursor = xml_skip(codes, named)
  if xml_starts(codes, cursor, "SYSTEM") {
    cursor = xml_literal(codes, cursor + 6)
    let (sysid, after) = xml_quoted(codes, cursor)
    info.put(xml_word(env, "sysid"), text_series(sysid))
    cursor = after
  } else if xml_starts(codes, cursor, "PUBLIC") {
    cursor = xml_literal(codes, cursor + 6)
    let (pubid, after_pub) = xml_quoted(codes, cursor)
    info.put(xml_word(env, "pubid"), text_series(pubid))
    if after_pub >= codes.length() || !xml_space(codes[after_pub]) {
      raise EvalError::Cannot("decode")
    }
    cursor = xml_skip(codes, after_pub)
    let (sysid, after_sys) = xml_quoted(codes, cursor)
    info.put(xml_word(env, "sysid"), text_series(sysid))
    cursor = after_sys
  }
  cursor = xml_skip(codes, cursor)
  if cursor < codes.length() && codes[cursor] == '['.to_int() {
    let end = xml_find(codes, cursor + 1, "]")
    info.put(
      xml_word(env, "subset"),
      text_series(xml_slice(codes, cursor + 1, end - 1)),
    )
    cursor = xml_skip(codes, end)
  }
  if cursor >= codes.length() || codes[cursor] != '>'.to_int() {
    raise EvalError::Cannot("decode")
  }
  cursor + 1
}

///|
fn xml_literal(codes : Array[Int], at : Int) -> Int raise EvalError {
  if at >= codes.length() || !xml_space(codes[at]) {
    raise EvalError::Cannot("decode")
  }
  xml_skip(codes, at)
}

///|
fn xml_find(
  codes : Array[Int],
  at : Int,
  marker : String,
) -> Int raise EvalError {
  let mut cursor = at
  let mut found = false
  while cursor < codes.length() && !found {
    if xml_starts(codes, cursor, marker) {
      found = true
    } else {
      cursor = cursor + 1
    }
  }
  if !found {
    raise EvalError::Cannot("decode")
  }
  let mut width = 0
  for char in marker {
    let _ = char
    width = width + 1
  }
  cursor + width
}

///|
fn xml_declaration(
  env : Env,
  codes : Array[Int],
  at : Int,
  info : @value.MapValue,
) -> Int raise EvalError {
  let (attrs, cursor) = xml_attrs(codes, at)
  if !xml_starts(codes, cursor, "?>") {
    raise EvalError::Cannot("decode")
  }
  match attrs {
    @value.Cell::None => ()
    @value.Seq(series, index) => {
      let mut slot = index
      while slot + 1 < series.length() {
        match (series.item(slot), series.item(slot + 1)) {
          (Some(key), Some(cell)) =>
            match key {
              @value.Seq(text, start) =>
                info.put(xml_word(env, text_from(text, start)), cell)
              _ => raise EvalError::Cannot("decode")
            }
          _ => raise EvalError::Cannot("decode")
        }
        slot = slot + 2
      }
    }
    _ => raise EvalError::Cannot("decode")
  }
  cursor + 2
}

///|
fn xml_element(
  env : Env,
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int) raise EvalError {
  if at + 1 >= codes.length() || codes[at] != '<'.to_int() {
    raise EvalError::Cannot("decode")
  }
  let mark = codes[at + 1]
  if mark == '/'.to_int() || mark == '!'.to_int() || mark == '?'.to_int() {
    raise EvalError::Cannot("decode")
  }
  let (name, named) = xml_name(codes, at + 1)
  let (attrs, cursor) = xml_attrs(codes, named)
  if xml_starts(codes, cursor, "/>") {
    return (xml_node(name, attrs, @value.Cell::None), cursor + 2)
  }
  if cursor >= codes.length() || codes[cursor] != '>'.to_int() {
    raise EvalError::Cannot("decode")
  }
  let kids = @value.Series::block()
  let mut count = 0
  let mut cursor = cursor + 1
  let mut closed = false
  while !closed && cursor < codes.length() {
    if xml_starts(codes, cursor, "</") {
      let (end_name, after) = xml_name(codes, cursor + 2)
      let tail = xml_skip(codes, after)
      if end_name != name ||
        tail >= codes.length() ||
        codes[tail] != '>'.to_int() {
        raise EvalError::Cannot("decode")
      }
      cursor = tail + 1
      closed = true
    } else if codes[cursor] == '<'.to_int() {
      let (child, after) = xml_element(env, codes, cursor)
      kids.push_item(child) |> ignore
      count = count + 1
      cursor = after
    } else {
      let (raw, after) = xml_text(codes, cursor)
      let decoded = xml_entities(raw)
      if decoded != "" {
        kids.push_item(text_series(decoded)) |> ignore
        count = count + 1
      }
      cursor = after
    }
  }
  if !closed {
    raise EvalError::Cannot("decode")
  }
  let content = if count == 0 { @value.Cell::None } else { @value.Seq(kids, 0) }
  (xml_node(name, attrs, content), cursor)
}

///|
fn xml_attrs(
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int) raise EvalError {
  let series = @value.Series::block()
  let mut count = 0
  let mut cursor = at
  let mut reading = true
  while reading {
    cursor = xml_skip(codes, cursor)
    if cursor >= codes.length() {
      raise EvalError::Cannot("decode")
    }
    let code = codes[cursor]
    if code == '>'.to_int() || code == '/'.to_int() || code == '?'.to_int() {
      reading = false
    } else {
      let (name, named) = xml_name(codes, cursor)
      cursor = xml_skip(codes, named)
      if cursor >= codes.length() || codes[cursor] != '='.to_int() {
        raise EvalError::Cannot("decode")
      }
      cursor = xml_skip(codes, cursor + 1)
      let (raw, after) = xml_quoted(codes, cursor)
      series.push_item(text_series(name)) |> ignore
      series.push_item(text_series(xml_entities(raw))) |> ignore
      count = count + 1
      cursor = after
    }
  }
  if count == 0 {
    (@value.Cell::None, cursor)
  } else {
    (@value.Seq(series, 0), cursor)
  }
}

///|
fn xml_node(
  name : String,
  attrs : @value.Cell,
  content : @value.Cell,
) -> @value.Cell {
  let block = @value.Series::block()
  block.push_item(text_series(name)) |> ignore
  block.push_item(attrs) |> ignore
  block.push_item(content) |> ignore
  @value.Seq(block, 0)
}

///|
fn xml_name(codes : Array[Int], at : Int) -> (String, Int) raise EvalError {
  let mut cursor = at
  while cursor < codes.length() && !xml_name_end(codes[cursor]) {
    cursor = cursor + 1
  }
  if cursor == at {
    raise EvalError::Cannot("decode")
  }
  (xml_slice(codes, at, cursor), cursor)
}

///|
fn xml_quoted(codes : Array[Int], at : Int) -> (String, Int) raise EvalError {
  if at >= codes.length() {
    raise EvalError::Cannot("decode")
  }
  let quote = codes[at]
  if quote != '"'.to_int() && quote != '\''.to_int() {
    raise EvalError::Cannot("decode")
  }
  let mut cursor = at + 1
  while cursor < codes.length() && codes[cursor] != quote {
    cursor = cursor + 1
  }
  if cursor >= codes.length() {
    raise EvalError::Cannot("decode")
  }
  (xml_slice(codes, at + 1, cursor), cursor + 1)
}

///|
fn xml_text(codes : Array[Int], at : Int) -> (String, Int) {
  let mut cursor = at
  while cursor < codes.length() && codes[cursor] != '<'.to_int() {
    cursor = cursor + 1
  }
  (xml_slice(codes, at, cursor), cursor)
}

///|
fn xml_entities(text : String) -> String raise EvalError {
  match decode_html(text_series(text)) {
    @value.Seq(series, index) => text_from(series, index)
    _ => raise EvalError::Cannot("decode")
  }
}

///|
fn xml_word(env : Env, name : String) -> @value.Cell {
  let sym = env.symbols.intern(name)
  @value.Sym(@value.Word, @value.Lexeme::make(sym, name))
}

///|
fn xml_slice(codes : Array[Int], from : Int, until : Int) -> String {
  let buf = StringBuilder()
  for index in from..<until {
    buf.write_char(codes[index].to_char().unwrap())
  }
  buf.to_string()
}

///|
fn xml_starts(codes : Array[Int], at : Int, text : String) -> Bool {
  let mut index = 0
  let mut ok = true
  for char in text {
    if at + index >= codes.length() || codes[at + index] != char.to_int() {
      ok = false
    }
    index = index + 1
  }
  ok && index > 0
}

///|
fn xml_skip(codes : Array[Int], at : Int) -> Int {
  let mut cursor = at
  while cursor < codes.length() && xml_space(codes[cursor]) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn xml_space(code : Int) -> Bool {
  code == ' '.to_int() ||
  code == '\t'.to_int() ||
  code == '\n'.to_int() ||
  code == '\r'.to_int()
}

///|
fn xml_name_end(code : Int) -> Bool {
  xml_space(code) ||
  code == '='.to_int() ||
  code == '<'.to_int() ||
  code == '>'.to_int() ||
  code == '/'.to_int() ||
  code == '?'.to_int() ||
  code == '"'.to_int() ||
  code == '\''.to_int()
}
