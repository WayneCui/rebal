///|
/// `load/as 'markup` splits tags from the text between them.
/// A `<` starts a tag only when the next character is a letter, `/`, `?`, or `!`.
/// An unclosed tag drops the `<` and the rest stays text.
fn decode_markup(source : @value.Cell) -> @value.Cell raise EvalError {
  let chars = markup_chars(source_text(source))
  let block = @value.Series::block()
  let mut cp = 0
  let mut bp = 0
  let mut len = chars.length()
  while len > 0 {
    while len > 0 && cp < chars.length() && chars[cp] != '<' {
      len = len - 1
      cp = cp + 1
    }
    if len > 0 && markup_opens(chars, cp) {
      if cp != bp {
        block.push_item(markup_piece(chars, bp, cp, @value.String)) |> ignore
      }
      cp = cp + 1
      bp = cp
      let skipped = markup_comment(chars, cp, len)
      cp = skipped.0
      len = skipped.1
      let scanned = markup_tag(chars, block, cp, bp, len)
      cp = scanned.0
      bp = scanned.1
      len = scanned.2
    } else if len > 0 {
      cp = cp + 1
      len = len - 1
    }
  }
  if cp != bp {
    block.push_item(markup_piece(chars, bp, cp, @value.String)) |> ignore
  }
  @value.Seq(block, 0)
}

///|
fn markup_chars(text : String) -> Array[Char] {
  let chars : Array[Char] = []
  for char in text {
    chars.push(char)
  }
  chars
}

///|
fn markup_opens(chars : Array[Char], cp : Int) -> Bool {
  let next = cp + 1
  if next >= chars.length() {
    false
  } else {
    let char = chars[next]
    (char >= 'A' && char <= 'Z') ||
    (char >= 'a' && char <= 'z') ||
    char == '/' ||
    char == '?' ||
    char == '!'
  }
}

///|
/// `<!-- ... -->` is still one tag. The scan only has to land on the closing `>`.
fn markup_comment(chars : Array[Char], cp : Int, len : Int) -> (Int, Int) {
  let n = chars.length()
  if cp < n &&
    chars[cp] == '!' &&
    len > 7 &&
    cp + 2 < n &&
    chars[cp + 1] == '-' &&
    chars[cp + 2] == '-' {
    let mut at = cp + 3
    let mut left = len - 3
    while left > 2 &&
          at < n &&
          !(at + 2 < n &&
          chars[at] == '-' &&
          chars[at + 1] == '-' &&
          chars[at + 2] == '>') {
      at = at + 1
      left = left - 1
    }
    if left > 2 && at + 2 <= n {
      (at + 2, left - 2)
    } else {
      (at, left)
    }
  } else {
    (cp, len)
  }
}

///|
fn markup_tag(
  chars : Array[Char],
  block : @value.Series,
  cp : Int,
  bp : Int,
  len : Int,
) -> (Int, Int, Int) {
  let n = chars.length()
  let mut at = cp
  let mut start = bp
  let mut left = len - 1
  let mut running = left > 0 && at < n
  while running {
    if chars[at] == '>' {
      block.push_item(markup_piece(chars, start, at, @value.Tag)) |> ignore
      at = at + 1
      start = at
      left = left - 1
      running = false
    } else if chars[at] == '"' || chars[at] == '\'' {
      let quote = chars[at]
      at = at + 1
      left = left - 1
      while left > 0 && at < n && chars[at] != quote {
        left = left - 1
        at = at + 1
      }
      if left <= 0 || at >= n {
        running = false
      } else {
        at = at + 1
        left = left - 1
        running = left > 0 && at < n
      }
    } else {
      at = at + 1
      left = left - 1
      running = left > 0 && at < n
    }
  }
  (at, start, left)
}

///|
fn markup_piece(
  chars : Array[Char],
  start : Int,
  end : Int,
  datatype : @value.Datatype,
) -> @value.Cell {
  let series = @value.Series::text_of(datatype)
  let from = if start < 0 { 0 } else { start }
  let to = if end > chars.length() { chars.length() } else { end }
  if from < to {
    for index in from..<to {
      series.push_code(chars[index].to_int()) |> ignore
    }
  }
  @value.Seq(series, 0)
}
