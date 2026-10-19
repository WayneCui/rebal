///|
/// `copy` takes `/deep` to copy nested series as well. A map is cloned
/// either way; its values stay shared. `/part` keeps only the first n
/// values, counted from the series position.
fn perform_copy(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let value = args[0]
  let mut deep = false
  let mut part : Int? = None
  let mut slot = 1
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "deep" {
      deep = true
    } else if name == "part" {
      part = Some(copy_part_count(args[slot]))
      slot = slot + 1
    } else {
      raise EvalError::Cannot("copy")
    }
  }
  match value {
    @value.Seq(series, index) => {
      let copied = match part {
        Some(count) =>
          if deep {
            series.copy_span(index, count).copy_deep(0)
          } else {
            series.copy_span(index, count)
          }
        None =>
          if deep {
            series.copy_deep(index)
          } else {
            series.copy_from(index)
          }
      }
      @value.Seq(copied, 0)
    }
    @value.Map(map) =>
      if part is Some(_) {
        raise EvalError::Cannot("copy")
      } else {
        @value.Map(map.copy())
      }
    _ =>
      if deep || part is Some(_) {
        raise EvalError::Cannot("copy")
      } else {
        from_action(@action.copy(value))
      }
  }
}

///|
fn copy_part_count(cell : @value.Cell) -> Int raise EvalError {
  match cell {
    @value.Integer(n) =>
      if n <= 0 {
        0
      } else if n > 2147483647L {
        2147483647
      } else {
        n.to_int()
      }
    _ => raise EvalError::Cannot("copy")
  }
}
