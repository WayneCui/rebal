///|
priv struct Rng {
  mut state : UInt64
}

///|
let rng : Rng = { state: 0x9E3779B97F4A7C15UL, }

///|
fn next_u64() -> UInt64 {
  let mixed = rng.state * 6364136223846793005UL + 1442695040888963407UL
  rng.state = mixed
  mixed
}

///|
/// Half away from zero, to a whole number.
pub fn round(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match cell {
    @value.Integer(n) => Ok(@value.Integer(n))
    @value.Decimal(n) => Ok(@value.Decimal(away(n)))
    @value.Percent(n) => Ok(@value.Percent(away(n * 100.0) / 100.0))
    @value.Money(n) => Ok(@value.Money(away(n)))
    @value.Time(n) => Ok(@value.Time(@value.snap_seconds(away(n))))
    _ => Err(Cannot("round"))
  }
}

///|
/// Integer result is from 1 through `n`, or -1 through `n` when `n` is negative.
pub fn random(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match cell {
    @value.Integer(n) => Ok(@value.Integer(random_int(n)))
    @value.Decimal(n) => Ok(@value.Decimal(random_unit() * n))
    @value.Time(n) => Ok(@value.Time(@value.snap_seconds(random_unit() * n)))
    _ => Err(Cannot("random"))
  }
}

///|
pub fn complement(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match cell {
    @value.Integer(n) => Ok(@value.Integer(0L - n - 1L))
    _ => Err(Cannot("complement"))
  }
}

///|
/// A positive count shifts left. Overflow of a signed integer is an error.
pub fn shift(
  value : @value.Cell,
  count : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match (value, count) {
    (@value.Integer(n), @value.Integer(bits)) =>
      match shift_exact(n, bits) {
        Some(shifted) => Ok(@value.Integer(shifted))
        None => Err(Cannot("shift"))
      }
    _ => Err(Cannot("shift"))
  }
}

///|
pub fn shift_left(
  value : @value.Cell,
  count : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match (value, count) {
    (@value.Integer(n), @value.Integer(bits)) =>
      Ok(@value.Integer(shift_wrapped(n, bits, true)))
    _ => Err(Cannot("shift"))
  }
}

///|
pub fn shift_right(
  value : @value.Cell,
  count : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match (value, count) {
    (@value.Integer(n), @value.Integer(bits)) =>
      Ok(@value.Integer(shift_wrapped(n, bits, false)))
    _ => Err(Cannot("shift"))
  }
}

///|
fn away(value : Double) -> Double {
  if value >= 0.0 {
    (value + 0.5).to_int64().to_double()
  } else {
    (value - 0.5).to_int64().to_double()
  }
}

///|
fn random_unit() -> Double {
  let mixed = next_u64()
  mixed.reinterpret_as_int64().to_double().abs() / 9223372036854775807.0
}

///|
fn random_int(limit : Int64) -> Int64 {
  if limit == 0L {
    0L
  } else {
    let span = if limit < 0L { 0L - limit } else { limit }
    let pick = (next_u64() % span.reinterpret_as_uint64()).reinterpret_as_int64() +
      1L
    if limit < 0L {
      0L - pick
    } else {
      pick
    }
  }
}

///|
fn shift_exact(value : Int64, bits : Int64) -> Int64? {
  if bits >= 0L {
    shift_left_exact(value, bits)
  } else {
    Some(shift_right_arith(value, 0L - bits))
  }
}

///|
fn shift_left_exact(value : Int64, bits : Int64) -> Int64? {
  if bits == 0L {
    Some(value)
  } else if bits >= 64L {
    if value == 0L {
      Some(0L)
    } else {
      None
    }
  } else {
    let mut current = value
    let mut left = bits
    let mut overflow = false
    while left > 0L && !overflow {
      if current > 4611686011777387903L || current < -4611686011777387904L {
        overflow = true
      } else {
        current = current * 2L
        left = left - 1L
      }
    }
    if overflow {
      None
    } else {
      Some(current)
    }
  }
}

///|
fn shift_right_arith(value : Int64, bits : Int64) -> Int64 {
  if bits >= 64L {
    if value < 0L {
      -1L
    } else {
      0L
    }
  } else {
    let mut current = value
    let mut left = bits
    while left > 0L {
      if current >= 0L {
        current = current / 2L
      } else {
        current = (current - 1L) / 2L
      }
      left = left - 1L
    }
    current
  }
}

///|
fn shift_wrapped(value : Int64, bits : Int64, left : Bool) -> Int64 {
  let span = if bits < 0L { 0L - bits } else { bits }
  let reduced = span % 64L
  if left {
    match shift_left_exact(value, reduced) {
      Some(shifted) => shifted
      None => 0L
    }
  } else {
    shift_right_arith(value, reduced)
  }
}
