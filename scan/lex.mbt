///|
priv struct Lexer {
  chars : Array[Char]
  mut pos : Int
  symbols : @value.Symbols
}

///|
pub fn transcode(
  source : String,
  symbols : @value.Symbols,
) -> Result[@value.Cell, ScanError] {
  let chars : Array[Char] = []
  for char in source {
    chars.push(char)
  }
  let lexer = { chars, pos: 0, symbols, }
  let block = @value.Series::block()
  while lexer.has() &&
        !(lexer.peek() is Some(']')) &&
        !(lexer.peek() is Some(')')) {
    match lexer.value() {
      Ok(cell) => block.push_item(cell) |> ignore
      Err(error) => return Err(error)
    }
  }
  if lexer.has() {
    Err(Invalid("extra"))
  } else {
    Ok(@value.Seq(block, 0))
  }
}

///|
fn Lexer::has(self : Lexer) -> Bool {
  self.skip_space()
  self.pos < self.chars.length()
}

///|
fn Lexer::peek(self : Lexer) -> Char? {
  self.chars.get(self.pos)
}

///|
fn Lexer::bump(self : Lexer) -> Char? {
  let char = self.peek()
  if char is Some(_) {
    self.pos = self.pos + 1
  }
  char
}

///|
fn Lexer::skip_space(self : Lexer) -> Unit {
  while self.pos < self.chars.length() {
    let char = self.chars[self.pos]
    if char == ';' {
      self.pos = self.pos + 1
      while self.pos < self.chars.length() && self.chars[self.pos] != '\n' {
        self.pos = self.pos + 1
      }
    } else if char == ' ' ||
      char == '\t' ||
      char == '\n' ||
      char == '\r' ||
      char == ',' {
      self.pos = self.pos + 1
    } else {
      break
    }
  }
}

///|
fn Lexer::value(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.skip_space()
  let scanned = match self.peek() {
    None => Err(Missing("value"))
    Some('[') => self.nested(@value.Series::block(), ']', "]")
    Some('(') => self.nested(@value.Series::paren(), ')', ")")
    Some('"') => self.string()
    Some('{') => self.braced()
    Some('#') => self.hash()
    Some('%') => self.file()
    Some('<') if self.looks_like_tag() => self.tag()
    Some('$') => self.money(1.0)
    Some('-') if self.signed_money() => self.signed_money_value(-1.0)
    Some('+') if self.signed_money() => self.signed_money_value(1.0)
    Some(':') => self.get_word()
    Some('\'') => self.lit_word()
    Some('/') => self.refinement()
    Some(char) if self.starts_number(char) => self.number()
    Some(_) => self.word()
  }
  self.maybe_path(scanned)
}

///|
fn Lexer::signed_money(self : Lexer) -> Bool {
  match self.chars.get(self.pos + 1) {
    Some('$') => true
    _ => false
  }
}

///|
fn Lexer::signed_money_value(
  self : Lexer,
  sign : Double,
) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  self.money(sign)
}

///|
fn Lexer::money(self : Lexer, sign : Double) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  match self.number() {
    Ok(@value.Integer(n)) => Ok(@value.Money(n.to_double() * sign))
    Ok(@value.Decimal(n)) => Ok(@value.Money(n * sign))
    Ok(_) => Err(Invalid("money"))
    Err(error) => Err(error)
  }
}

///|
fn Lexer::starts_number(self : Lexer, char : Char) -> Bool {
  if is_digit(char) {
    true
  } else if char == '+' || char == '-' {
    match self.chars.get(self.pos + 1) {
      Some(next) => is_digit(next)
      None => false
    }
  } else {
    false
  }
}

///|
fn Lexer::nested(
  self : Lexer,
  series : @value.Series,
  end : Char,
  missing : String,
) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  let mut result : Result[@value.Cell, ScanError] = Err(Missing(missing))
  let mut open = true
  while open {
    self.skip_space()
    match self.peek() {
      None => open = false
      Some(char) if char == end => {
        self.bump() |> ignore
        result = Ok(@value.Seq(series, 0))
        open = false
      }
      _ =>
        match self.value() {
          Ok(cell) => series.push_item(cell) |> ignore
          Err(error) => {
            result = Err(error)
            open = false
          }
        }
    }
  }
  result
}

///|
fn Lexer::maybe_path(
  self : Lexer,
  value : Result[@value.Cell, ScanError],
) -> Result[@value.Cell, ScanError] {
  match value {
    Err(error) => Err(error)
    Ok(cell) => {
      let path = @value.Series::path()
      path.push_item(cell) |> ignore
      while self.glued_slash() {
        self.bump() |> ignore
        match self.path_element() {
          Ok(element) => path.push_item(element) |> ignore
          Err(error) => return Err(error)
        }
      }
      if path.length() == 1 {
        Ok(cell)
      } else {
        Ok(@value.Seq(path, 0))
      }
    }
  }
}

///|
fn Lexer::glued_slash(self : Lexer) -> Bool {
  if self.peek() is Some('/') {
    match self.chars.get(self.pos + 1) {
      Some(char) => !is_space(char) && char != '/' && char != ']' && char != ')'
      None => false
    }
  } else {
    false
  }
}

///|
fn Lexer::path_element(self : Lexer) -> Result[@value.Cell, ScanError] {
  match self.peek() {
    Some(char) if is_digit(char) => self.number()
    Some(_) => self.plain_word(@value.Word)
    None => Err(Invalid("path"))
  }
}

///|
fn Lexer::get_word(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  match self.peek() {
    Some(char) if is_word_start(char) => self.plain_word(@value.GetWord)
    _ => Err(Invalid("get-word"))
  }
}

///|
fn Lexer::lit_word(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  match self.peek() {
    Some(char) if is_word_start(char) || is_digit(char) =>
      self.plain_word(@value.LitWord)
    _ => Err(Invalid("lit-word"))
  }
}

///|
fn Lexer::refinement(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  match self.peek() {
    Some('/') => {
      self.bump() |> ignore
      self.plain_word_from("//", @value.Word)
    }
    Some(char) if !is_space(char) && char != ']' && char != ')' =>
      self.plain_word(@value.Refinement)
    _ => self.plain_word_from("/", @value.Word)
  }
}

///|
fn Lexer::word(self : Lexer) -> Result[@value.Cell, ScanError] {
  let start = self.pos
  match self.any_string() {
    Some(datatype) => self.take_text(datatype, start)
    None => {
      self.pos = start
      self.plain_word(@value.Word)
    }
  }
}

///|
fn Lexer::plain_word(
  self : Lexer,
  datatype : @value.Datatype,
) -> Result[@value.Cell, ScanError] {
  let start = self.pos
  if self.bump() is None {
    return Err(Invalid("word"))
  }
  while (match self.peek() {
          Some(char) => is_word_char(char)
          None => false
        }) {
    self.bump() |> ignore
  }
  let mut end = self.pos
  let mut kind = datatype
  if datatype == @value.Word && end > start + 1 && self.chars[end - 1] == ':' {
    end = end - 1
    kind = @value.SetWord
  }
  let spelling = chars_text(self.chars, start, end)
  if spelling == "" {
    Err(Invalid("word"))
  } else {
    let sym = self.symbols.intern(spelling)
    Ok(@value.Sym(kind, @value.Lexeme::make(sym, spelling)))
  }
}

///|
fn Lexer::plain_word_from(
  self : Lexer,
  spelling : String,
  datatype : @value.Datatype,
) -> Result[@value.Cell, ScanError] {
  let sym = self.symbols.intern(spelling)
  Ok(@value.Sym(datatype, @value.Lexeme::make(sym, spelling)))
}

///|
fn is_digit(char : Char) -> Bool {
  char >= '0' && char <= '9'
}

///|
fn is_space(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\n' || char == '\r' || char == ','
}

///|
fn is_word_start(char : Char) -> Bool {
  is_word_char(char) && !is_digit(char)
}

///|
fn is_word_char(char : Char) -> Bool {
  (char >= 'A' && char <= 'Z') ||
  (char >= 'a' && char <= 'z') ||
  is_digit(char) ||
  char == '+' ||
  char == '-' ||
  char == '*' ||
  char == '=' ||
  char == '<' ||
  char == '>' ||
  char == '?' ||
  char == '!' ||
  char == '.' ||
  char == '_' ||
  char == '\'' ||
  char == '&' ||
  char == '|' ||
  char == '~' ||
  char == ':'
}

///|
fn chars_text(chars : Array[Char], start : Int, end : Int) -> String {
  let buf = StringBuilder()
  for i in start..<end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}
