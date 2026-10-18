///|
/// Depth limit so a cyclic block cannot loop forever.
let max_compare_depth : Int = 32

///|
/// Coerced equality. Mismatched types that do not coerce are false.
pub fn equal(left : @value.Cell, right : @value.Cell) -> Bool {
  equal_at(left, right, 0)
}

///|
/// Strict codepoint and numeric order. Types that cannot be ordered fail.
pub fn lesser(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[Bool, ActionError] {
  match order(left, right, 0) {
    Ok(n) => Ok(n < 0)
    Err(error) => Err(error)
  }
}

///|
pub fn greater(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[Bool, ActionError] {
  match order(left, right, 0) {
    Ok(n) => Ok(n > 0)
    Err(error) => Err(error)
  }
}

///|
pub fn lesser_or_equal(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[Bool, ActionError] {
  match greater(left, right) {
    Ok(flag) => Ok(!flag)
    Err(error) => Err(error)
  }
}

///|
pub fn greater_or_equal(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[Bool, ActionError] {
  match lesser(left, right) {
    Ok(flag) => Ok(!flag)
    Err(error) => Err(error)
  }
}

///|
/// Same datatype and same payload. Numbers do not coerce. Text keeps its case.
pub fn strict_equal(left : @value.Cell, right : @value.Cell) -> Bool {
  match (left, right) {
    (@value.Handle(a), @value.Handle(b)) => a.same(b)
    _ => left.equal(right)
  }
}

///|
fn equal_at(left : @value.Cell, right : @value.Cell, depth : Int) -> Bool {
  if depth > max_compare_depth {
    false
  } else {
    match number_order(left, right) {
      Some(n) => n == 0
      None => equal_rest(left, right, depth)
    }
  }
}

///|
fn equal_rest(left : @value.Cell, right : @value.Cell, depth : Int) -> Bool {
  match (left, right) {
    (@value.Char(a), @value.Char(b)) => fold_code(a) == fold_code(b)
    (@value.Char(a), @value.Integer(b)) => a.to_int64() == b
    (@value.Integer(a), @value.Char(b)) => a == b.to_int64()
    (@value.Seq(a, ai), @value.Seq(b, bi)) => series_equal(a, ai, b, bi, depth)
    _ => left.equal(right)
  }
}

///|
fn series_equal(
  left : @value.Series,
  left_index : Int,
  right : @value.Series,
  right_index : Int,
  depth : Int,
) -> Bool {
  if left.datatype() != right.datatype() {
    false
  } else if left.datatype() == @value.String {
    text_cmp(left, left_index, right, right_index, true) == 0
  } else if is_marked_text(left) {
    text_cmp(left, left_index, right, right_index, false) == 0
  } else if left.datatype() == @value.Binary {
    byte_cmp(left, left_index, right, right_index) == 0
  } else if is_items(left) {
    items_equal(left, left_index, right, right_index, depth)
  } else {
    false
  }
}

///|
fn order(
  left : @value.Cell,
  right : @value.Cell,
  depth : Int,
) -> Result[Int, ActionError] {
  if depth > max_compare_depth {
    Err(Cannot("compare"))
  } else {
    match number_order(left, right) {
      Some(n) => Ok(n)
      None => order_rest(left, right, depth)
    }
  }
}

///|
fn order_rest(
  left : @value.Cell,
  right : @value.Cell,
  depth : Int,
) -> Result[Int, ActionError] {
  match (left, right) {
    (@value.Char(a), @value.Char(b)) => Ok(cmp_int(a, b))
    (@value.Char(a), @value.Integer(b)) => Ok(cmp_int64(a.to_int64(), b))
    (@value.Integer(a), @value.Char(b)) => Ok(cmp_int64(a, b.to_int64()))
    (@value.Seq(a, ai), @value.Seq(b, bi)) => series_order(a, ai, b, bi, depth)
    (@value.Handle(a), @value.Handle(b)) => Ok(kind_order(a.kind(), b.kind()))
    _ => Err(Cannot("compare"))
  }
}

///|
fn series_order(
  left : @value.Series,
  left_index : Int,
  right : @value.Series,
  right_index : Int,
  depth : Int,
) -> Result[Int, ActionError] {
  if left.datatype() != right.datatype() {
    Err(Cannot("compare"))
  } else if left.datatype() == @value.String || is_marked_text(left) {
    Ok(text_cmp(left, left_index, right, right_index, false))
  } else if left.datatype() == @value.Binary {
    Ok(byte_cmp(left, left_index, right, right_index))
  } else if is_items(left) {
    items_order(left, left_index, right, right_index, depth)
  } else {
    Err(Cannot("compare"))
  }
}

///|
fn kind_order(left : String, right : String) -> Int {
  text_cmp(kind_text(left), 0, kind_text(right), 0, false)
}

///|
fn kind_text(value : String) -> @value.Series {
  let series = @value.Series::text()
  for char in value {
    series.push_code(char.to_int()) |> ignore
  }
  series
}

///|
fn is_marked_text(series : @value.Series) -> Bool {
  series.datatype() == @value.File ||
  series.datatype() == @value.Email ||
  series.datatype() == @value.Url ||
  series.datatype() == @value.Tag ||
  series.datatype() == @value.Issue
}

///|
fn tuple_order(left : Array[Int], right : Array[Int]) -> Int? {
  if left.length() != right.length() {
    None
  } else {
    let mut found = 0
    for i in 0..<left.length() {
      if found == 0 {
        found = cmp_int(left[i], right[i])
      }
    }
    Some(found)
  }
}

///|
fn number_order(left : @value.Cell, right : @value.Cell) -> Int? {
  match (left, right) {
    (@value.Integer(x), @value.Integer(y)) => Some(cmp_int64(x, y))
    (@value.Integer(x), @value.Decimal(y)) => Some(cmp_double(x.to_double(), y))
    (@value.Decimal(x), @value.Integer(y)) => Some(cmp_double(x, y.to_double()))
    (@value.Decimal(x), @value.Decimal(y)) => Some(cmp_double(x, y))
    (@value.Pair(x, y), @value.Pair(a, b)) =>
      if x != a {
        Some(cmp_int64(x, a))
      } else {
        Some(cmp_int64(y, b))
      }
    (@value.Tuple(left), @value.Tuple(right)) => tuple_order(left, right)
    (@value.Time(x), @value.Time(y)) => Some(cmp_double(x, y))
    (@value.Time(x), @value.Integer(y)) => Some(cmp_double(x, y.to_double()))
    (@value.Integer(x), @value.Time(y)) => Some(cmp_double(x.to_double(), y))
    (@value.Time(x), @value.Decimal(y)) => Some(cmp_double(x, y))
    (@value.Decimal(x), @value.Time(y)) => Some(cmp_double(x, y))
    (@value.Time(x), @value.Percent(y)) => Some(cmp_double(x, y))
    (@value.Percent(x), @value.Time(y)) => Some(cmp_double(x, y))
    (@value.Date(left), @value.Date(right)) => Some(left.order(right))
    _ =>
      match (as_double(left), as_double(right)) {
        (Some(x), Some(y)) if left.datatype() == @value.Percent ||
          right.datatype() == @value.Percent ||
          left.datatype() == @value.Money ||
          right.datatype() == @value.Money => Some(cmp_double(x, y))
        _ => None
      }
  }
}

///|
fn items_equal(
  left : @value.Series,
  left_index : Int,
  right : @value.Series,
  right_index : Int,
  depth : Int,
) -> Bool {
  let left_len = tail_len(left.length(), left_index)
  let right_len = tail_len(right.length(), right_index)
  if left_len != right_len {
    false
  } else {
    let mut ok = true
    let mut offset = 0
    while offset < left_len && ok {
      match
        (
          left.item(start_at(left_index) + offset),
          right.item(start_at(right_index) + offset),
        ) {
        (Some(a), Some(b)) => if !equal_at(a, b, depth + 1) { ok = false }
        _ => ok = false
      }
      offset = offset + 1
    }
    ok
  }
}

///|
fn items_order(
  left : @value.Series,
  left_index : Int,
  right : @value.Series,
  right_index : Int,
  depth : Int,
) -> Result[Int, ActionError] {
  let left_len = tail_len(left.length(), left_index)
  let right_len = tail_len(right.length(), right_index)
  let shared = if left_len < right_len { left_len } else { right_len }
  let mut offset = 0
  let mut found : Result[Int, ActionError] = Ok(0)
  while offset < shared && found is Ok(0) {
    found = match
      (
        left.item(start_at(left_index) + offset),
        right.item(start_at(right_index) + offset),
      ) {
      (Some(a), Some(b)) => order(a, b, depth + 1)
      _ => Err(Cannot("compare"))
    }
    offset = offset + 1
  }
  match found {
    Ok(0) => Ok(cmp_int(left_len, right_len))
    other => other
  }
}

///|
fn text_cmp(
  left : @value.Series,
  left_index : Int,
  right : @value.Series,
  right_index : Int,
  fold : Bool,
) -> Int {
  let left_len = tail_len(left.length(), left_index)
  let right_len = tail_len(right.length(), right_index)
  let shared = if left_len < right_len { left_len } else { right_len }
  let mut offset = 0
  let mut found = 0
  while offset < shared && found == 0 {
    let a = folded(left, start_at(left_index) + offset, fold)
    let b = folded(right, start_at(right_index) + offset, fold)
    found = cmp_int(a, b)
    offset = offset + 1
  }
  if found != 0 {
    found
  } else {
    cmp_int(left_len, right_len)
  }
}

///|
fn byte_cmp(
  left : @value.Series,
  left_index : Int,
  right : @value.Series,
  right_index : Int,
) -> Int {
  let left_len = tail_len(left.length(), left_index)
  let right_len = tail_len(right.length(), right_index)
  let shared = if left_len < right_len { left_len } else { right_len }
  let mut offset = 0
  let mut found = 0
  while offset < shared && found == 0 {
    found = cmp_int(
      byte_code(left, start_at(left_index) + offset),
      byte_code(right, start_at(right_index) + offset),
    )
    offset = offset + 1
  }
  if found != 0 {
    found
  } else {
    cmp_int(left_len, right_len)
  }
}

///|
fn is_items(series : @value.Series) -> Bool {
  match series.datatype() {
    @value.Block | @value.Paren | @value.Path | @value.SetPath => true
    _ => false
  }
}

///|
fn folded(series : @value.Series, index : Int, fold : Bool) -> Int {
  match series.code(index) {
    Some(code) => if fold { fold_code(code) } else { code }
    None => 0
  }
}

///|
fn byte_code(series : @value.Series, index : Int) -> Int {
  match series.byte_at(index) {
    Some(byte) => byte.to_int()
    None => 0
  }
}

///|
fn fold_code(code : Int) -> Int {
  if code >= 'A'.to_int() && code <= 'Z'.to_int() {
    code + ('a'.to_int() - 'A'.to_int())
  } else {
    code
  }
}

///|
fn start_at(index : Int) -> Int {
  if index < 0 {
    0
  } else {
    index
  }
}

///|
fn tail_len(length : Int, index : Int) -> Int {
  let start = start_at(index)
  if start >= length {
    0
  } else {
    length - start
  }
}

///|
fn cmp_int(left : Int, right : Int) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn cmp_int64(left : Int64, right : Int64) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn cmp_double(left : Double, right : Double) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}
