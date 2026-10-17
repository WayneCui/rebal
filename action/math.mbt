///|
pub fn add(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  combine(left, right, "add", fn(x, y) { x + y }, fn(x, y) { x + y })
}

///|
pub fn subtract(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  combine(left, right, "subtract", fn(x, y) { x - y }, fn(x, y) { x - y })
}

///|
pub fn multiply(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  combine(left, right, "multiply", fn(x, y) { x * y }, fn(x, y) { x * y })
}

///|
fn combine(
  left : @value.Cell,
  right : @value.Cell,
  name : String,
  on_int : (Int64, Int64) -> Int64,
  on_decimal : (Double, Double) -> Double,
) -> Result[@value.Cell, ActionError] {
  match (left, right) {
    (@value.Integer(x), @value.Integer(y)) => Ok(@value.Integer(on_int(x, y)))
    (@value.Integer(x), @value.Decimal(y)) =>
      Ok(@value.Decimal(on_decimal(x.to_double(), y)))
    (@value.Decimal(x), @value.Integer(y)) =>
      Ok(@value.Decimal(on_decimal(x, y.to_double())))
    (@value.Decimal(x), @value.Decimal(y)) =>
      Ok(@value.Decimal(on_decimal(x, y)))
    (@value.Percent(x), @value.Percent(y)) =>
      Ok(@value.Percent(on_decimal(x, y)))
    (@value.Pair(x, y), @value.Pair(a, b)) =>
      Ok(@value.Pair(on_int(x, a), on_int(y, b)))
    (@value.Pair(x, y), @value.Integer(n)) =>
      Ok(@value.Pair(on_int(x, n), on_int(y, n)))
    (@value.Integer(n), @value.Pair(x, y)) =>
      Ok(@value.Pair(on_int(n, x), on_int(n, y)))
    (@value.Tuple(left), @value.Tuple(right)) =>
      combine_tuple(left, right, name, on_int)
    _ =>
      match (as_double(left), as_double(right)) {
        (Some(x), Some(y)) => Ok(@value.Decimal(on_decimal(x, y)))
        _ => Err(Cannot(name))
      }
  }
}

///|
fn combine_tuple(
  left : Array[Int],
  right : Array[Int],
  name : String,
  on_int : (Int64, Int64) -> Int64,
) -> Result[@value.Cell, ActionError] {
  if left.length() != right.length() || left.length() == 0 {
    Err(Cannot(name))
  } else {
    let out : Array[Int] = []
    let mut bad = false
    for i in 0..<left.length() {
      let value = on_int(left[i].to_int64(), right[i].to_int64())
      if value < 0L || value > 255L {
        bad = true
      } else {
        out.push(value.to_int())
      }
    }
    if bad {
      Err(Cannot(name))
    } else {
      Ok(@value.Tuple(out))
    }
  }
}

///|
fn as_double(cell : @value.Cell) -> Double? {
  match cell {
    @value.Integer(n) => Some(n.to_double())
    @value.Decimal(n) | @value.Percent(n) => Some(n)
    _ => None
  }
}
