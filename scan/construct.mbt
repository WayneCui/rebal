///|
/// `#(string! "123" 2)` restores a series at a 1-based index.
/// The value is the head, and the index is optional. Past the tail means the tail.
fn Lexer::construct(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  let kind = match self.value() {
    Ok(@value.Sym(@value.Word, lexeme)) => self.symbols.canon(lexeme.sym())
    _ => return Err(Invalid("construct"))
  }
  if kind == "map!" {
    return self.construct_map()
  }
  let value = match self.value() {
    Ok(cell) => cell
    Err(_) => return Err(Invalid("construct"))
  }
  self.skip_space()
  let placed = match self.peek() {
    Some(')') => place_series(kind, value, 1L)
    Some(char) if is_digit(char) =>
      match self.number() {
        Ok(@value.Integer(index)) => place_series(kind, value, index)
        _ => Err(Invalid("construct"))
      }
    _ => Err(Invalid("construct"))
  }
  self.skip_space()
  match self.bump() {
    Some(')') => placed
    _ => Err(Invalid("construct"))
  }
}

///|

///|
/// `#(map! [a: 1 "b" 2])` rebuilds a map. A set-word is a word key.
fn Lexer::construct_map(self : Lexer) -> Result[@value.Cell, ScanError] {
  let value = match self.value() {
    Ok(cell) => cell
    Err(_) => return Err(Invalid("construct"))
  }
  self.skip_space()
  match self.bump() {
    Some(')') => map_from_block(value)
    _ => Err(Invalid("construct"))
  }
}

///|
fn map_from_block(value : @value.Cell) -> Result[@value.Cell, ScanError] {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let map = @value.MapValue::make()
      let mut cursor = if index < 0 { 0 } else { index }
      while cursor < series.length() {
        match series.item(cursor) {
          None => return Err(Invalid("construct"))
          Some(key) => {
            let stored = match key {
              @value.Sym(@value.SetWord, lexeme) =>
                @value.Sym(
                  @value.Word,
                  @value.Lexeme::make(lexeme.sym(), lexeme.spelling()),
                )
              other => other
            }
            cursor = cursor + 1
            match series.item(cursor) {
              Some(item) => map.put(stored, item)
              None => return Err(Invalid("construct"))
            }
            cursor = cursor + 1
          }
        }
      }
      Ok(@value.Map(map))
    }
    _ => Err(Invalid("construct"))
  }
}

///|
fn place_series(
  kind : String,
  value : @value.Cell,
  index : Int64,
) -> Result[@value.Cell, ScanError] {
  if index < 1L || index > 2147483647L {
    Err(Invalid("construct"))
  } else {
    match value {
      @value.Seq(series, _) if construct_kind(kind, series.datatype()) => {
        let zero = (index - 1L).to_int()
        let at = if zero > series.length() { series.length() } else { zero }
        Ok(@value.Seq(series, at))
      }
      _ => Err(Invalid("construct"))
    }
  }
}

///|
fn construct_kind(kind : String, datatype : @value.Datatype) -> Bool {
  match datatype {
    @value.String => kind == "string!"
    @value.Binary => kind == "binary!"
    @value.Block => kind == "block!"
    _ => false
  }
}
