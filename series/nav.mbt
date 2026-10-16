///|
fn view(cell : @value.Cell) -> (@value.Series, Int)? {
  match cell {
    @value.Seq(series, index) => Some((series, index))
    _ => None
  }
}

///|
fn clamp(index : Int, length : Int) -> Int {
  if index < 0 {
    0
  } else if index > length {
    length
  } else {
    index
  }
}

///|
pub fn length(cell : @value.Cell) -> Int? {
  match view(cell) {
    Some((series, index)) => Some(series.length() - index)
    None => None
  }
}

///|
/// Rebol `index?` is 1-based.
pub fn index(cell : @value.Cell) -> Int? {
  match view(cell) {
    Some((_, index)) => Some(index + 1)
    None => None
  }
}

///|
pub fn is_tail(cell : @value.Cell) -> Bool? {
  match view(cell) {
    Some((series, index)) => Some(index >= series.length())
    None => None
  }
}

///|
pub fn head(cell : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, _)) => Some(@value.Seq(series, 0))
    None => None
  }
}

///|
pub fn tail(cell : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, _)) => Some(@value.Seq(series, series.length()))
    None => None
  }
}

///|
pub fn next(cell : @value.Cell) -> @value.Cell? {
  skip(cell, 1)
}

///|
pub fn skip(cell : @value.Cell, n : Int) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) =>
      Some(@value.Seq(series, clamp(index + n, series.length())))
    None => None
  }
}

///|
/// `at` is 1-based. Positions outside the series land on the head or the tail.
pub fn at(cell : @value.Cell, n : Int) -> @value.Cell? {
  match view(cell) {
    Some((series, _)) => Some(@value.Seq(series, clamp(n - 1, series.length())))
    None => None
  }
}

///|
pub fn pick(cell : @value.Cell, n : Int) -> @value.Cell {
  match view(cell) {
    Some((series, index)) => {
      let pos = index + n - 1
      match series.datatype() {
        @value.Block | @value.Paren | @value.Path | @value.SetPath =>
          match series.item(pos) {
            Some(value) => value
            None => @value.None
          }
        @value.String =>
          match series.code(pos) {
            Some(code) => @value.Char(code)
            None => @value.None
          }
        @value.Binary =>
          match series.byte_at(pos) {
            Some(byte) => @value.Integer(byte.to_int64())
            None => @value.None
          }
        _ => @value.None
      }
    }
    None => @value.None
  }
}

///|
pub fn poke(cell : @value.Cell, n : Int, value : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) => {
      let pos = index + n - 1
      let wrote = match (series.datatype(), value) {
        (@value.String, @value.Char(code)) => replace_code(series, pos, code)
        (@value.Binary, @value.Integer(byte)) =>
          if byte >= 0L && byte <= 255L {
            replace_byte(series, pos, byte.to_byte())
          } else {
            false
          }
        (@value.Block | @value.Paren | @value.Path | @value.SetPath, _) =>
          series.set_item(pos, value)
        _ => false
      }
      if wrote {
        Some(cell)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn replace_code(series : @value.Series, pos : Int, code : Int) -> Bool {
  match series.remove_code(pos) {
    Some(_) => series.insert_code(pos, code)
    None => false
  }
}

///|
fn replace_byte(series : @value.Series, pos : Int, byte : Byte) -> Bool {
  match series.remove_byte(pos) {
    Some(_) => series.insert_byte(pos, byte)
    None => false
  }
}

///|
pub fn copy(cell : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) => Some(@value.Seq(series.copy_from(index), 0))
    None => None
  }
}
