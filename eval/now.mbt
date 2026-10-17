///|
extern "C" fn c_read_clock(utc : Int, precise : Int) -> Unit = "rebal_read_clock"

///|
extern "C" fn c_clock_year() -> Int = "rebal_clock_year"

///|
extern "C" fn c_clock_month() -> Int = "rebal_clock_month"

///|
extern "C" fn c_clock_day() -> Int = "rebal_clock_day"

///|
extern "C" fn c_clock_zone() -> Int = "rebal_clock_zone"

///|
extern "C" fn c_clock_weekday() -> Int = "rebal_clock_weekday"

///|
extern "C" fn c_clock_yearday() -> Int = "rebal_clock_yearday"

///|
extern "C" fn c_clock_seconds() -> Double = "rebal_clock_seconds"

///|
/// Local date and time. `/utc` uses universal time. One of `/year`, `/month`,
/// `/day`, `/time`, `/zone`, `/date`, `/weekday`, or `/yearday` picks a part.
/// Monday is weekday 1. `/precise` keeps a fraction of a second.
fn perform_now(env : Env, active : Array[Int]) -> @value.Cell raise EvalError {
  let mut part = ""
  let mut utc = false
  let mut precise = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "utc" {
      utc = true
    } else if name == "precise" {
      precise = true
    } else if name == "year" ||
      name == "month" ||
      name == "day" ||
      name == "time" ||
      name == "zone" ||
      name == "date" ||
      name == "weekday" ||
      name == "yearday" {
      if part != "" {
        raise EvalError::Cannot("now")
      }
      part = name
    } else {
      raise EvalError::Cannot("now")
    }
  }
  c_read_clock(if utc { 1 } else { 0 }, if precise { 1 } else { 0 })
  let year = c_clock_year()
  let month = c_clock_month()
  let day = c_clock_day()
  let seconds = @value.snap_seconds(c_clock_seconds())
  let zone = c_clock_zone()
  if part == "year" {
    @value.Integer(year.to_int64())
  } else if part == "month" {
    @value.Integer(month.to_int64())
  } else if part == "day" {
    @value.Integer(day.to_int64())
  } else if part == "weekday" {
    @value.Integer(c_clock_weekday().to_int64())
  } else if part == "yearday" {
    @value.Integer(c_clock_yearday().to_int64())
  } else if part == "time" {
    @value.Time(seconds)
  } else if part == "zone" {
    @value.Time(zone.to_double() * 60.0)
  } else if part == "date" {
    @value.Date(@value.DateValue::make(year, month, day, None, None))
  } else {
    @value.Date(
      @value.DateValue::make(year, month, day, Some(seconds), Some(zone)),
    )
  }
}
