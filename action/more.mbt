///|
pub fn divide(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  if zero_cell(right) {
    Err(Cannot("divide"))
  } else {
    match (left, right) {
      (@value.Integer(x), @value.Integer(y)) =>
        if x % y == 0L {
          Ok(@value.Integer(x / y))
        } else {
          Ok(@value.Decimal(x.to_double() / y.to_double()))
        }
      (@value.Time(x), @value.Time(y)) => Ok(@value.Decimal(x / y))
      (@value.Time(x), @value.Integer(y)) =>
        Ok(@value.Time(@value.snap_seconds(x / y.to_double())))
      (@value.Time(x), @value.Decimal(y)) =>
        Ok(@value.Time(@value.snap_seconds(x / y)))
      (@value.Money(x), @value.Integer(y)) =>
        Ok(@value.Money(x / y.to_double()))
      (@value.Money(x), @value.Decimal(y)) => Ok(@value.Money(x / y))
      (@value.Percent(x), @value.Integer(y)) =>
        Ok(@value.Percent(x / y.to_double()))
      (@value.Percent(x), @value.Decimal(y)) => Ok(@value.Percent(x / y))
      _ =>
        match (as_double(left), as_double(right)) {
          (Some(x), Some(y)) => Ok(@value.Decimal(x / y))
          _ => Err(Cannot("divide"))
        }
    }
  }
}

///|
pub fn remainder(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  if zero_cell(right) {
    Err(Cannot("remainder"))
  } else {
    match (left, right) {
      (@value.Integer(x), @value.Integer(y)) => Ok(@value.Integer(x % y))
      _ =>
        match (as_double(left), as_double(right)) {
          (Some(x), Some(y)) =>
            Ok(@value.Decimal(x - (x / y).to_int64().to_double() * y))
          _ => Err(Cannot("remainder"))
        }
    }
  }
}

///|
pub fn power(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match (as_double(left), as_double(right)) {
    (Some(base), Some(exp)) =>
      match raised(base, exp) {
        Some(value) => Ok(@value.Decimal(value))
        None => Err(Cannot("power"))
      }
    _ => Err(Cannot("power"))
  }
}

///|
pub fn negate(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match cell {
    @value.Integer(n) => Ok(@value.Integer(0L - n))
    @value.Decimal(n) => Ok(@value.Decimal(0.0 - n))
    @value.Percent(n) => Ok(@value.Percent(0.0 - n))
    @value.Money(n) => Ok(@value.Money(0.0 - n))
    @value.Time(n) => Ok(@value.Time(@value.snap_seconds(0.0 - n)))
    @value.Pair(x, y) => Ok(@value.Pair(0L - x, 0L - y))
    _ => Err(Cannot("negate"))
  }
}

///|
pub fn absolute(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match cell {
    @value.Integer(n) => Ok(@value.Integer(if n < 0L { 0L - n } else { n }))
    @value.Decimal(n) => Ok(@value.Decimal(if n < 0.0 { 0.0 - n } else { n }))
    @value.Percent(n) => Ok(@value.Percent(if n < 0.0 { 0.0 - n } else { n }))
    @value.Money(n) => Ok(@value.Money(if n < 0.0 { 0.0 - n } else { n }))
    @value.Time(n) =>
      Ok(@value.Time(@value.snap_seconds(if n < 0.0 { 0.0 - n } else { n })))
    @value.Pair(x, y) =>
      Ok(
        @value.Pair(
          if x < 0L {
            0L - x
          } else {
            x
          },
          if y < 0L {
            0L - y
          } else {
            y
          },
        ),
      )
    _ => Err(Cannot("absolute"))
  }
}

///|
pub fn odd_q(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match whole_seconds(cell) {
    Some(n) => Ok(@value.Logic(n % 2L != 0L))
    None => Err(Cannot("odd?"))
  }
}

///|
pub fn even_q(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match whole_seconds(cell) {
    Some(n) => Ok(@value.Logic(n % 2L == 0L))
    None => Err(Cannot("even?"))
  }
}

///|
pub fn negative_q(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match signed_number(cell) {
    Some(n) => Ok(@value.Logic(n < 0.0))
    None => Err(Cannot("negative?"))
  }
}

///|
pub fn positive_q(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match signed_number(cell) {
    Some(n) => Ok(@value.Logic(n > 0.0))
    None => Err(Cannot("positive?"))
  }
}

///|
pub fn zero_q(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match signed_number(cell) {
    Some(n) => Ok(@value.Logic(n == 0.0))
    None => Err(Cannot("zero?"))
  }
}

///|
pub fn minimum(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match order(left, right, 0) {
    Ok(n) => if n <= 0 { Ok(left) } else { Ok(right) }
    Err(error) => Err(error)
  }
}

///|
pub fn maximum(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match order(left, right, 0) {
    Ok(n) => if n >= 0 { Ok(left) } else { Ok(right) }
    Err(error) => Err(error)
  }
}

///|
fn zero_cell(cell : @value.Cell) -> Bool {
  match signed_number(cell) {
    Some(n) => n == 0.0
    None => false
  }
}

///|
fn signed_number(cell : @value.Cell) -> Double? {
  match cell {
    @value.Time(n) => Some(n)
    @value.Pair(_, _) => None
    _ => as_double(cell)
  }
}

///|
fn whole_seconds(cell : @value.Cell) -> Int64? {
  match cell {
    @value.Integer(n) => Some(n)
    @value.Time(n) => Some(n.to_int64())
    _ => None
  }
}

///|
fn raised(base : Double, exp : Double) -> Double? {
  let as_int = exp.to_int64()
  if as_int.to_double() != exp || as_int > 40L || as_int < -40L {
    None
  } else if as_int < 0L {
    let denom = ipow(base, 0L - as_int)
    if denom == 0.0 {
      None
    } else {
      Some(1.0 / denom)
    }
  } else {
    Some(ipow(base, as_int))
  }
}

///|
fn ipow(base : Double, exp : Int64) -> Double {
  let mut result = 1.0
  let mut count = 0L
  while count < exp {
    result = result * base
    count = count + 1L
  }
  result
}
