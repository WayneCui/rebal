///|
fn item_span(series : @value.Series, index : Int) -> Array[@value.Cell] {
  let out : Array[@value.Cell] = []
  for i in index..<series.length() {
    match series.item(i) {
      Some(cell) => out.push(cell.snapshot())
      None => ()
    }
  }
  out
}

///|
fn code_span(series : @value.Series, index : Int) -> Array[Int] {
  let out : Array[Int] = []
  for i in index..<series.length() {
    match series.code(i) {
      Some(code) => out.push(code)
      None => ()
    }
  }
  out
}

///|
fn splice(series : @value.Series, index : Int, value : @value.Cell) -> Int? {
  match value {
    @value.Seq(source, source_index) =>
      if series.datatype() == @value.Block &&
        (source.datatype() == @value.Block || source.datatype() == @value.Paren) {
        let span = item_span(source, source_index)
        for i in 0..<span.length() {
          series.insert_item(index + i, span[i]) |> ignore
        }
        Some(span.length())
      } else if series.datatype() == @value.String &&
        source.datatype() == @value.String {
        let span = code_span(source, source_index)
        for i in 0..<span.length() {
          series.insert_code(index + i, span[i]) |> ignore
        }
        Some(span.length())
      } else {
        splice_one(series, index, value)
      }
    _ => splice_one(series, index, value)
  }
}

///|
fn splice_one(series : @value.Series, index : Int, value : @value.Cell) -> Int? {
  match (series.datatype(), value) {
    (@value.String, @value.Char(code)) =>
      if series.insert_code(index, code) {
        Some(1)
      } else {
        None
      }
    (@value.Block | @value.Paren | @value.Path | @value.SetPath, _) =>
      if series.insert_item(index, value.snapshot()) {
        Some(1)
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn insert(cell : @value.Cell, value : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) =>
      match splice(series, index, value) {
        Some(count) => Some(@value.Seq(series, index + count))
        None => None
      }
    None => None
  }
}

///|
pub fn append(cell : @value.Cell, value : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) =>
      match splice(series, series.length(), value) {
        Some(_) => Some(@value.Seq(series, index))
        None => None
      }
    None => None
  }
}

///|
pub fn remove(cell : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) => {
      let removed = match series.datatype() {
        @value.String => series.remove_code(index) is Some(_)
        @value.Binary => series.remove_byte(index) is Some(_)
        @value.Block | @value.Paren | @value.Path | @value.SetPath =>
          series.remove_item(index) is Some(_)
        _ => false
      }
      if removed {
        Some(@value.Seq(series, index))
      } else {
        Some(cell)
      }
    }
    None => None
  }
}

///|
pub fn find(cell : @value.Cell, value : @value.Cell) -> @value.Cell {
  match view(cell) {
    Some((series, index)) =>
      match find_at(series, index, value) {
        Some(found) => @value.Seq(series, found)
        None => @value.None
      }
    None => @value.None
  }
}

///|
fn find_at(series : @value.Series, index : Int, value : @value.Cell) -> Int? {
  match series.datatype() {
    @value.Block | @value.Paren | @value.Path | @value.SetPath => {
      let mut found : Int? = None
      for i in index..<series.length() {
        if found is None {
          match series.item(i) {
            Some(item) if item.equal(value) => found = Some(i)
            _ => ()
          }
        }
      }
      found
    }
    @value.String =>
      match seek_code(value) {
        Some(code) => {
          let mut found : Int? = None
          for i in index..<series.length() {
            if found is None {
              match series.code(i) {
                Some(at) if at == code => found = Some(i)
                _ => ()
              }
            }
          }
          found
        }
        None => None
      }
    _ => None
  }
}

///|
/// An integer in a string matches the digit character, so `find "123" 2` is `"23"`.
fn seek_code(value : @value.Cell) -> Int? {
  match value {
    @value.Char(code) => Some(code)
    @value.Integer(n) =>
      if n >= 0L && n <= 9L {
        Some('0'.to_int() + n.to_int())
      } else {
        None
      }
    _ => None
  }
}
