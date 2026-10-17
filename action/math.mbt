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
    (@value.Money(x), @value.Money(y)) => Ok(@value.Money(on_decimal(x, y)))
    (@value.Money(x), @value.Integer(y)) =>
      Ok(@value.Money(on_decimal(x, y.to_double())))
    (@value.Money(x), @value.Decimal(y)) => Ok(@value.Money(on_decimal(x, y)))
    (@value.Integer(x), @value.Money(y)) =>
      Ok(@value.Money(on_decimal(x.to_double(), y)))
    (@value.Decimal(x), @value.Money(y)) => Ok(@value.Money(on_decimal(x, y)))
    (@value.Time(x), @value.Time(y)) =>
      if name == "add" || name == "subtract" {
        Ok(@value.Time(@value.snap_seconds(on_decimal(x, y))))
      } else {
        Err(Cannot(name))
      }
    (@value.Time(x), @value.Integer(y)) =>
      time_pair(name, on_decimal(x, y.to_double()))
    (@value.Time(x), @value.Decimal(y)) => time_pair(name, on_decimal(x, y))
    (@value.Integer(x), @value.Time(y)) =>
      time_pair(name, on_decimal(x.to_double(), y))
    (@value.Decimal(x), @value.Time(y)) => time_pair(name, on_decimal(x, y))
    (@value.Time(x), @value.Percent(y)) => time_percent(name, on_decimal(x, y))
    (@value.Percent(x), @value.Time(y)) => time_percent(name, on_decimal(x, y))
    (@value.Time(x), @value.Money(y)) =>
      time_money(name, on_decimal(x / 3600.0, y))
    (@value.Money(x), @value.Time(y)) =>
      time_money(name, on_decimal(x, y / 3600.0))
    (@value.Date(date), @value.Integer(n)) =>
      shift_date(name, date, n.to_int(), true)
    (@value.Integer(n), @value.Date(date)) =>
      shift_date(name, date, n.to_int(), false)
    (@value.Date(left), @value.Date(right)) =>
      if name == "subtract" {
        Ok(@value.Integer(left.day_diff(right).to_int64()))
      } else {
        Err(Cannot(name))
      }
    (@value.Date(date), @value.Time(seconds)) =>
      add_date_time(name, date, seconds)
    (@value.Time(seconds), @value.Date(date)) =>
      add_date_time(name, date, seconds)
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
fn time_pair(
  name : String,
  seconds : Double,
) -> Result[@value.Cell, ActionError] {
  if name == "add" || name == "subtract" || name == "multiply" {
    Ok(@value.Time(@value.snap_seconds(seconds)))
  } else {
    Err(Cannot(name))
  }
}

///|
fn time_percent(
  name : String,
  seconds : Double,
) -> Result[@value.Cell, ActionError] {
  if name == "multiply" {
    Ok(@value.Time(@value.snap_seconds(seconds)))
  } else {
    Err(Cannot(name))
  }
}

///|
fn time_money(
  name : String,
  amount : Double,
) -> Result[@value.Cell, ActionError] {
  if name == "multiply" {
    Ok(@value.Money(amount))
  } else {
    Err(Cannot(name))
  }
}

///|
fn shift_date(
  name : String,
  date : @value.DateValue,
  days : Int,
  date_on_left : Bool,
) -> Result[@value.Cell, ActionError] {
  if name == "add" {
    Ok(@value.Date(date.shift(days)))
  } else if name == "subtract" && date_on_left {
    Ok(@value.Date(date.shift(0 - days)))
  } else {
    Err(Cannot(name))
  }
}

///|
fn add_date_time(
  name : String,
  date : @value.DateValue,
  seconds : Double,
) -> Result[@value.Cell, ActionError] {
  if name == "add" {
    Ok(@value.Date(date.add_seconds(seconds)))
  } else {
    Err(Cannot(name))
  }
}

///|
fn as_double(cell : @value.Cell) -> Double? {
  match cell {
    @value.Integer(n) => Some(n.to_double())
    @value.Decimal(n) | @value.Percent(n) | @value.Money(n) => Some(n)
    _ => None
  }
}
