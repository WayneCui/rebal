///|
pub fn clear(cell : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) => {
      let start = if index < 0 { 0 } else { index }
      let mut left = series.length() - start
      if left < 0 {
        left = 0
      }
      for _ in 0..<left {
        drop_at(series, start)
      }
      Some(@value.Seq(series, start))
    }
    None => None
  }
}

///|
/// Removes the value at the current index and returns that value.
pub fn take(cell : @value.Cell) -> @value.Cell? {
  match view(cell) {
    None => None
    Some((series, index)) =>
      if index < 0 || index >= series.length() {
        Some(@value.None)
      } else {
        Some(pull(series, index))
      }
  }
}

///|
pub fn reverse(cell : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) => {
      let start = if index < 0 { 0 } else { index }
      match series.datatype() {
        @value.String => {
          let span = code_span(series, start)
          refill_codes(series, start, span)
        }
        @value.Binary => {
          let span = byte_span(series, start)
          refill_bytes(series, start, span)
        }
        @value.Block | @value.Paren | @value.Path | @value.SetPath => {
          let span = item_span(series, start)
          refill_items(series, start, span)
        }
        _ => ()
      }
      Some(cell)
    }
    None => None
  }
}

///|
pub fn swap(left : @value.Cell, right : @value.Cell) -> @value.Cell? {
  match (view(left), view(right)) {
    (Some((a, i)), Some((b, j))) =>
      if exchange(a, i, b, j) {
        Some(left)
      } else {
        None
      }
    _ => None
  }
}

///|
/// Overwrites values at the index. A block or string value writes each element.
pub fn change(cell : @value.Cell, value : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) =>
      match written(series, index, value) {
        Some(count) => Some(@value.Seq(series, index + count))
        None => None
      }
    None => None
  }
}

///|
pub fn trim(cell : @value.Cell) -> @value.Cell? {
  match view(cell) {
    Some((series, index)) if series.datatype() == @value.String => {
      while series.length() > 0 {
        match series.code(0) {
          Some(code) if is_space_code(code) => drop_at(series, 0)
          _ => break
        }
      }
      let mut trimming = true
      while trimming && series.length() > 0 {
        match series.code(series.length() - 1) {
          Some(code) if is_space_code(code) =>
            drop_at(series, series.length() - 1)
          _ => trimming = false
        }
      }
      let at = if index < 0 {
        0
      } else if index > series.length() {
        series.length()
      } else {
        index
      }
      Some(@value.Seq(series, at))
    }
    _ => None
  }
}

///|
fn drop_at(series : @value.Series, index : Int) -> Unit {
  match series.datatype() {
    @value.String => series.remove_code(index) |> ignore
    @value.Binary => series.remove_byte(index) |> ignore
    _ => series.remove_item(index) |> ignore
  }
}

///|
fn pull(series : @value.Series, index : Int) -> @value.Cell {
  match series.datatype() {
    @value.String =>
      match series.remove_code(index) {
        Some(code) => @value.Char(code)
        None => @value.None
      }
    @value.Binary =>
      match series.remove_byte(index) {
        Some(byte) => @value.Integer(byte.to_int().to_int64())
        None => @value.None
      }
    _ =>
      match series.remove_item(index) {
        Some(cell) => cell
        None => @value.None
      }
  }
}

///|
fn refill_codes(series : @value.Series, index : Int, span : Array[Int]) -> Unit {
  let count = span.length()
  for _ in 0..<count {
    series.remove_code(index) |> ignore
  }
  for i in 0..<count {
    series.insert_code(index + i, span[count - 1 - i]) |> ignore
  }
}

///|
fn refill_items(
  series : @value.Series,
  index : Int,
  span : Array[@value.Cell],
) -> Unit {
  let count = span.length()
  for _ in 0..<count {
    series.remove_item(index) |> ignore
  }
  for i in 0..<count {
    series.insert_item(index + i, span[count - 1 - i]) |> ignore
  }
}

///|
fn refill_bytes(
  series : @value.Series,
  index : Int,
  span : Array[Byte],
) -> Unit {
  let count = span.length()
  for _ in 0..<count {
    series.remove_byte(index) |> ignore
  }
  for i in 0..<count {
    series.insert_byte(index + i, span[count - 1 - i]) |> ignore
  }
}

///|
fn byte_span(series : @value.Series, index : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  for i in index..<series.length() {
    match series.byte_at(i) {
      Some(byte) => out.push(byte)
      None => ()
    }
  }
  out
}

///|
fn exchange(
  left : @value.Series,
  left_index : Int,
  right : @value.Series,
  right_index : Int,
) -> Bool {
  if left_index < 0 ||
    right_index < 0 ||
    left_index >= left.length() ||
    right_index >= right.length() {
    false
  } else if left.datatype() == @value.String &&
    right.datatype() == @value.String {
    match (left.code(left_index), right.code(right_index)) {
      (Some(a), Some(b)) =>
        replace_code(left, left_index, b) && replace_code(right, right_index, a)
      _ => false
    }
  } else if is_items(left) && is_items(right) {
    match (left.item(left_index), right.item(right_index)) {
      (Some(a), Some(b)) =>
        left.set_item(left_index, b) && right.set_item(right_index, a)
      _ => false
    }
  } else {
    false
  }
}

///|
fn is_items(series : @value.Series) -> Bool {
  series.datatype() == @value.Block ||
  series.datatype() == @value.Paren ||
  series.datatype() == @value.Path ||
  series.datatype() == @value.SetPath
}

///|
fn written(series : @value.Series, index : Int, value : @value.Cell) -> Int? {
  let start = if index < 0 { 0 } else { index }
  if is_items(series) {
    match value {
      @value.Seq(source, source_index) if source.datatype() == @value.Block ||
        source.datatype() == @value.Paren => {
        let span = item_span(source, source_index)
        put_items(series, start, span)
        Some(span.length())
      }
      _ => {
        put_item(series, start, value.snapshot())
        Some(1)
      }
    }
  } else if series.datatype() == @value.String {
    match value {
      @value.Seq(source, source_index) if source.datatype() == @value.String => {
        let span = code_span(source, source_index)
        put_codes(series, start, span)
        Some(span.length())
      }
      @value.Char(code) => {
        put_code(series, start, code)
        Some(1)
      }
      _ => None
    }
  } else {
    None
  }
}

///|
fn put_items(
  series : @value.Series,
  index : Int,
  span : Array[@value.Cell],
) -> Unit {
  for i in 0..<span.length() {
    put_item(series, index + i, span[i])
  }
}

///|
fn put_item(series : @value.Series, index : Int, value : @value.Cell) -> Unit {
  if index < series.length() {
    series.set_item(index, value) |> ignore
  } else {
    series.push_item(value) |> ignore
  }
}

///|
fn put_codes(series : @value.Series, index : Int, span : Array[Int]) -> Unit {
  for i in 0..<span.length() {
    put_code(series, index + i, span[i])
  }
}

///|
fn put_code(series : @value.Series, index : Int, code : Int) -> Unit {
  if index < series.length() {
    replace_code(series, index, code) |> ignore
  } else {
    series.push_code(code) |> ignore
  }
}

///|
fn is_space_code(code : Int) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}
