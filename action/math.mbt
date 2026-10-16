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
    _ => Err(Cannot(name))
  }
}
