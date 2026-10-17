///|
fn Lexer::file(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  match self.peek() {
    Some('"') =>
      match self.string() {
        Ok(cell) => copy_text(cell, @value.File)
        Err(error) => Err(error)
      }
    _ => self.encoded_file()
  }
}

///|
fn Lexer::encoded_file(self : Lexer) -> Result[@value.Cell, ScanError] {
  let series = @value.Series::text_of(@value.File)
  let mut running = true
  while running {
    match self.peek() {
      Some('%') =>
        match self.percent_code() {
          Ok(code) => series.push_code(code) |> ignore
          Err(error) => return Err(error)
        }
      Some(char) if !is_token_end(char) => {
        series.push_code(char.to_int()) |> ignore
        self.bump() |> ignore
      }
      _ => running = false
    }
  }
  Ok(@value.Seq(series, 0))
}

///|
fn Lexer::percent_code(self : Lexer) -> Result[Int, ScanError] {
  self.bump() |> ignore
  match (self.bump(), self.bump()) {
    (Some(high), Some(low)) =>
      match (hex_value(high), hex_value(low)) {
        (Some(hi), Some(lo)) => Ok(hi * 16 + lo)
        _ => Err(Invalid("file"))
      }
    _ => Err(Invalid("file"))
  }
}

///|
fn Lexer::tag(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  let series = @value.Series::text_of(@value.Tag)
  let mut closed = false
  while !closed {
    match self.bump() {
      Some('>') => closed = true
      Some(char) => series.push_code(char.to_int()) |> ignore
      None => return Err(Missing(">"))
    }
  }
  Ok(@value.Seq(series, 0))
}

///|
fn Lexer::issue(self : Lexer) -> Result[@value.Cell, ScanError] {
  let start = self.pos
  while (match self.peek() {
          Some(char) => is_word_char(char)
          None => false
        }) {
    self.bump() |> ignore
  }
  self.take_text(@value.Issue, start)
}

///|
fn Lexer::looks_like_tag(self : Lexer) -> Bool {
  match self.chars.get(self.pos + 1) {
    None => false
    Some('>') | Some('=') => false
    Some(char) if is_space(char) => false
    _ => {
      let mut index = self.pos + 1
      let mut found = false
      while index < self.chars.length() && !found {
        let char = self.chars[index]
        if char == '>' {
          found = true
        } else if is_token_end(char) {
          index = self.chars.length()
        } else {
          index = index + 1
        }
      }
      found
    }
  }
}

///|
fn Lexer::any_string(self : Lexer) -> @value.Datatype? {
  if self.bump() is None {
    return None
  }
  let mut email = false
  let mut url = false
  let mut running = true
  while running {
    match self.peek() {
      Some('@') if !email && !url => {
        email = true
        self.bump() |> ignore
      }
      Some(':') if !email && !url =>
        match self.chars.get(self.pos + 1) {
          Some(char) if !is_token_end(char) => {
            url = true
            self.bump() |> ignore
          }
          _ => running = false
        }
      Some(char) if url && !is_token_end(char) => self.bump() |> ignore
      Some(char) if !url && is_word_char(char) => self.bump() |> ignore
      _ => running = false
    }
  }
  if email {
    Some(@value.Email)
  } else if url {
    Some(@value.Url)
  } else {
    None
  }
}

///|
fn Lexer::take_text(
  self : Lexer,
  datatype : @value.Datatype,
  start : Int,
) -> Result[@value.Cell, ScanError] {
  let series = @value.Series::text_of(datatype)
  for index in start..<self.pos {
    series.push_code(self.chars[index].to_int()) |> ignore
  }
  Ok(@value.Seq(series, 0))
}

///|
fn copy_text(
  cell : @value.Cell,
  datatype : @value.Datatype,
) -> Result[@value.Cell, ScanError] {
  match cell {
    @value.Seq(series, index) => {
      let copy = @value.Series::text_of(datatype)
      for at in index..<series.length() {
        match series.code(at) {
          Some(code) => copy.push_code(code) |> ignore
          None => ()
        }
      }
      Ok(@value.Seq(copy, 0))
    }
    _ => Err(Invalid("file"))
  }
}

///|
fn is_token_end(char : Char) -> Bool {
  is_space(char) ||
  char == '[' ||
  char == ']' ||
  char == '(' ||
  char == ')' ||
  char == '"' ||
  char == '{' ||
  char == '}' ||
  char == ';'
}

///|
fn hex_value(char : Char) -> Int? {
  if char >= '0' && char <= '9' {
    Some(char.to_int() - '0'.to_int())
  } else if char >= 'A' && char <= 'F' {
    Some(char.to_int() - 'A'.to_int() + 10)
  } else if char >= 'a' && char <= 'f' {
    Some(char.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}
