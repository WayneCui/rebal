///|
/// Search a series. `last` walks from the tail, `reverse` walks backward from
/// the current index, and `match_only` accepts only the current position.
/// `tail` returns the series past the match. `only` treats a block as one value.
/// `part` limits how many values from the current index may be searched.
pub fn find_with(
  cell : @value.Cell,
  value : @value.Cell,
  last : Bool,
  reverse : Bool,
  match_only : Bool,
  tail : Bool,
  only : Bool,
  part : Int?,
) -> @value.Cell {
  match view(cell) {
    Some((series, index)) => {
      let end = match part {
        Some(count) => clamp(index + count, series.length())
        None => series.length()
      }
      match locate(series, index, end, value, last, reverse, match_only, only) {
        Some(found) =>
          if tail {
            @value.Seq(series, found + span_of(series, value, only))
          } else {
            @value.Seq(series, found)
          }
        None => @value.None
      }
    }
    None => @value.None
  }
}

///|
pub fn select(cell : @value.Cell, value : @value.Cell) -> @value.Cell {
  match find_with(cell, value, false, false, false, false, false, None) {
    @value.Seq(series, found) => {
      let next = found + span_of(series, value, false)
      match series.datatype() {
        @value.String =>
          match series.code(next) {
            Some(code) => @value.Char(code)
            None => @value.None
          }
        _ =>
          match series.item(next) {
            Some(item) => item
            None => @value.None
          }
      }
    }
    _ => @value.None
  }
}

///|
fn locate(
  series : @value.Series,
  index : Int,
  end : Int,
  value : @value.Cell,
  last : Bool,
  reverse : Bool,
  match_only : Bool,
  only : Bool,
) -> Int? {
  let len = span_of(series, value, only)
  if len <= 0 {
    None
  } else if match_only {
    if index + len <= end && hits(series, index, value, only) {
      Some(index)
    } else {
      None
    }
  } else if last || reverse {
    let mut cursor = if last { end - len } else { index - 1 }
    let limit = if last { index } else { 0 }
    let mut found : Int? = None
    while found is None && cursor >= limit {
      if hits(series, cursor, value, only) {
        found = Some(cursor)
      } else {
        cursor = cursor - 1
      }
    }
    found
  } else {
    let mut cursor = index
    let mut found : Int? = None
    let last_start = end - len
    while found is None && cursor <= last_start {
      if hits(series, cursor, value, only) {
        found = Some(cursor)
      } else {
        cursor = cursor + 1
      }
    }
    found
  }
}

///|
/// How many positions a match covers. In a block a string is one value, so
/// its character length must not shrink the search window. Character length
/// only applies when the haystack itself is text.
fn span_of(series : @value.Series, value : @value.Cell, only : Bool) -> Int {
  if only {
    1
  } else if is_items(series) {
    match value {
      @value.Seq(source, source_index) if is_items(source) =>
        source.length() - source_index
      _ => 1
    }
  } else {
    match value {
      @value.Seq(source, source_index) if source.datatype() == @value.String =>
        source.length() - source_index
      @value.Seq(source, source_index) if is_items(source) =>
        source.length() - source_index
      _ => 1
    }
  }
}

///|
fn hits(
  series : @value.Series,
  at : Int,
  value : @value.Cell,
  only : Bool,
) -> Bool {
  if at < 0 || at >= series.length() {
    false
  } else if is_items(series) {
    match value {
      @value.Seq(source, source_index) if !only && is_items(source) =>
        same_items(series, at, source, source_index)
      _ =>
        match series.item(at) {
          Some(item) => item.equal(value)
          None => false
        }
    }
  } else if series.datatype() == @value.String {
    match value {
      @value.Seq(source, source_index) if source.datatype() == @value.String =>
        same_text(series, at, source, source_index)
      @value.Char(code) => series.code(at) == Some(code)
      @value.Integer(n) =>
        if n >= 0L && n <= 9L {
          series.code(at) == Some('0'.to_int() + n.to_int())
        } else {
          false
        }
      _ => false
    }
  } else {
    false
  }
}

///|
fn same_items(
  series : @value.Series,
  at : Int,
  source : @value.Series,
  source_index : Int,
) -> Bool {
  let len = source.length() - source_index
  if at + len > series.length() {
    false
  } else {
    let mut ok = len > 0
    for i in 0..<len {
      if ok {
        match (series.item(at + i), source.item(source_index + i)) {
          (Some(left), Some(right)) => ok = left.equal(right)
          _ => ok = false
        }
      }
    }
    ok
  }
}

///|
fn same_text(
  series : @value.Series,
  at : Int,
  source : @value.Series,
  source_index : Int,
) -> Bool {
  let len = source.length() - source_index
  if at + len > series.length() {
    false
  } else {
    let mut ok = len > 0
    for i in 0..<len {
      if ok {
        ok = fold_code(series.code(at + i)) == fold_code(source.code(source_index + i))
      }
    }
    ok
  }
}

///|
/// String matching folds case, the way r3's find compares text.
fn fold_code(code : Int?) -> Int? {
  match code {
    Some(value) =>
      if value >= 'A'.to_int() && value <= 'Z'.to_int() {
        Some(value + 32)
      } else {
        Some(value)
      }
    None => None
  }
}
