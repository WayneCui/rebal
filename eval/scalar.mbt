///|
fn to_percent(spec : @value.Cell, making : Bool) -> @value.Cell raise EvalError {
  match spec {
    @value.Integer(n) => @value.Percent(n.to_double())
    @value.Decimal(n) => @value.Percent(n)
    @value.Percent(n) => @value.Percent(n)
    @value.Logic(true) if making => @value.Percent(1.0)
    @value.Logic(false) if making => @value.Percent(0.0)
    _ => raise EvalError::Cannot(if making { "make" } else { "to" })
  }
}

///|
fn decimal_from(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Percent(n) => @value.Decimal(n)
    @value.Decimal(n) => @value.Decimal(n)
    @value.Integer(n) => @value.Decimal(n.to_double())
    @value.Time(n) => @value.Decimal(n)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn integer_from(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Percent(n) => @value.Integer(n.to_int64())
    @value.Integer(n) => @value.Integer(n)
    @value.Decimal(n) => @value.Integer(n.to_int64())
    @value.Time(n) => @value.Integer(n.to_int64())
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn to_pair(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Pair(x, y) => @value.Pair(x, y)
    @value.Integer(n) => @value.Pair(n, n)
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      match (series.item(index), series.item(index + 1)) {
        (Some(@value.Integer(x)), Some(@value.Integer(y))) => @value.Pair(x, y)
        _ => raise EvalError::Cannot("make")
      }
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn to_time(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Time(n) => @value.Time(n)
    @value.Integer(n) => @value.Time(@value.snap_seconds(n.to_double()))
    @value.Decimal(n) => @value.Time(@value.snap_seconds(n))
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      time_block(series, index)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn time_block(
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let count = series.length() - index
  if count < 1 || count > 3 {
    raise EvalError::Cannot("make")
  } else {
    match series.item(index) {
      Some(@value.Integer(hour)) => {
        let negative = hour < 0L
        let hours = if negative { 0L - hour } else { hour }
        let minute = if count == 1 {
          0.0
        } else {
          time_minute(series, index + 1)
        }
        let second = if count < 3 {
          0.0
        } else {
          time_second(series, index + 2)
        }
        let magnitude = hours.to_double() * 3600.0 + minute * 60.0 + second
        let seconds = if negative { 0.0 - magnitude } else { magnitude }
        @value.Time(@value.snap_seconds(seconds))
      }
      _ => raise EvalError::Cannot("make")
    }
  }
}

///|
fn time_minute(series : @value.Series, index : Int) -> Double raise EvalError {
  match series.item(index) {
    Some(@value.Integer(n)) if n >= 0L => n.to_double()
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn time_second(series : @value.Series, index : Int) -> Double raise EvalError {
  match series.item(index) {
    Some(@value.Integer(n)) if n >= 0L => n.to_double()
    Some(@value.Decimal(n)) if n >= 0.0 => n
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn to_money(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Money(n) => @value.Money(n)
    @value.Integer(n) => @value.Money(n.to_double())
    @value.Decimal(n) => @value.Money(n)
    @value.Percent(n) => @value.Money(n)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn to_tuple(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Tuple(parts) => @value.Tuple(parts)
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let parts : Array[Int] = []
      let mut cursor = index
      let mut bad = false
      while cursor < series.length() && !bad {
        match series.item(cursor) {
          Some(@value.Integer(n)) if n >= 0L && n <= 255L =>
            parts.push(n.to_int())
          _ => bad = true
        }
        cursor = cursor + 1
      }
      if bad || parts.length() < 3 || parts.length() > 12 {
        raise EvalError::Cannot("make")
      } else {
        @value.Tuple(parts)
      }
    }
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn perform_to(
  datatype : @value.Cell,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  match datatype {
    @value.Type(@value.Percent) => to_percent(spec, false)
    @value.Type(@value.Decimal) => decimal_from(spec)
    @value.Type(@value.Integer) => integer_from(spec)
    @value.Type(@value.Pair) => to_pair(spec)
    @value.Type(@value.Tuple) => to_tuple(spec)
    @value.Type(@value.Money) => to_money(spec)
    @value.Type(@value.Time) => to_time(spec)
    _ => raise EvalError::Cannot("to")
  }
}
