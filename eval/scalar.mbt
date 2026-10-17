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
fn to_date(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Date(date) => @value.Date(date)
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      date_block(series, index)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn date_block(
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  match series.item(index) {
    Some(@value.Date(date)) => date_from_date(date, series, index)
    Some(@value.Integer(day)) => date_from_parts(day, series, index)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn date_from_date(
  date : @value.DateValue,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let count = series.length() - index
  if count == 1 {
    @value.Date(date)
  } else if count == 2 {
    @value.Date(date.add_seconds(date_time_at(series, index + 1)))
  } else if count == 3 {
    let shifted = date.add_seconds(date_time_at(series, index + 1))
    @value.Date(
      @value.DateValue::make(
        shifted.year(),
        shifted.month(),
        shifted.day(),
        shifted.time(),
        Some(zone_minutes(date_time_at(series, index + 2))),
      ),
    )
  } else {
    raise EvalError::Cannot("make")
  }
}

///|
fn date_from_parts(
  day : Int64,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let count = series.length() - index
  if count < 3 || count > 5 {
    raise EvalError::Cannot("make")
  } else {
    match (series.item(index + 1), series.item(index + 2)) {
      (Some(@value.Integer(month)), Some(@value.Integer(year))) => {
        let y = year.to_int()
        let m = month.to_int()
        let d = day.to_int()
        if !@value.valid_date(y, m, d) {
          raise EvalError::Cannot("make")
        } else {
          let base = @value.DateValue::make(y, m, d, None, None)
          if count == 3 {
            @value.Date(base)
          } else if count == 4 {
            @value.Date(base.add_seconds(date_time_at(series, index + 3)))
          } else {
            let shifted = base.add_seconds(date_time_at(series, index + 3))
            @value.Date(
              @value.DateValue::make(
                shifted.year(),
                shifted.month(),
                shifted.day(),
                shifted.time(),
                Some(zone_minutes(date_time_at(series, index + 4))),
              ),
            )
          }
        }
      }
      _ => raise EvalError::Cannot("make")
    }
  }
}

///|
fn date_time_at(series : @value.Series, index : Int) -> Double raise EvalError {
  match series.item(index) {
    Some(@value.Time(seconds)) => seconds
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn zone_minutes(seconds : Double) -> Int {
  (seconds / 60.0).to_int()
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
    @value.Type(@value.Date) => to_date(spec)
    @value.Type(@value.Bitset) => to_bitset(spec)
    _ => raise EvalError::Cannot("to")
  }
}
