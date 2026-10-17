///|
extern "C" fn c_sleep(seconds : Double) -> Int = "rebal_sleep"

///|
/// Sleep for an integer, decimal, or time. A port, or a block of ports, has
/// no events yet, so it returns none. A number inside that block is the
/// timeout. `wait none` returns none.
fn perform_wait(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.None => @value.None
    @value.Port(_) => @value.None
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let mut delay : Double? = None
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(item) => delay = note_wait(item, delay)
          None => ()
        }
        cursor = cursor + 1
      }
      match delay {
        Some(seconds) => sleep_for(seconds)
        None => ()
      }
      @value.None
    }
    _ => {
      sleep_for(duration(value))
      @value.None
    }
  }
}

///|
fn note_wait(item : @value.Cell, delay : Double?) -> Double? raise EvalError {
  match item {
    @value.None | @value.Port(_) => delay
    _ =>
      match delay {
        Some(_) => raise EvalError::Cannot("wait")
        None => Some(duration(item))
      }
  }
}

///|
fn duration(value : @value.Cell) -> Double raise EvalError {
  match value {
    @value.Integer(n) => n.to_double()
    @value.Decimal(n) => n
    @value.Time(n) => n
    _ => raise EvalError::Cannot("wait")
  }
}

///|
fn sleep_for(seconds : Double) -> Unit raise EvalError {
  if c_sleep(seconds) != 0 {
    raise EvalError::Cannot("wait")
  }
}
