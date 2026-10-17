///|
/// `false` and `none` are the only false values.
fn falsey(cell : @value.Cell) -> Bool {
  match cell {
    @value.Logic(false) | @value.None => true
    _ => false
  }
}

///|
pub fn logic_not(cell : @value.Cell) -> @value.Cell {
  @value.Logic(falsey(cell))
}

///|
pub fn logic_and(left : @value.Cell, right : @value.Cell) -> @value.Cell {
  @value.Logic(!falsey(left) && !falsey(right))
}

///|
pub fn logic_or(left : @value.Cell, right : @value.Cell) -> @value.Cell {
  @value.Logic(!falsey(left) || !falsey(right))
}
