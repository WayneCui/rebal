///|
/// `copy` takes `/deep` to copy nested series as well. A map is cloned
/// either way; its values stay shared. `/part` keeps only the first n
/// values, counted from the series position. The part may also name an
/// end position: the same series at a later index bounds the span.
fn perform_copy(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let value = args[0]
  let mut deep = false
  let mut part : @value.Cell? = None
  let mut slot = 1
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "deep" {
      deep = true
    } else if name == "part" {
      part = Some(args[slot])
      slot = slot + 1
    } else {
      raise EvalError::Cannot("copy")
    }
  }
  match value {
    @value.Seq(series, index) => {
      let count = match part {
        Some(cell) => Some(copy_part_count(cell, @value.Seq(series, index)))
        None => None
      }
      let copied = match count {
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
/// The `/part` span count. An integer is a length. A series is an end
/// position: inside the same series the span runs to its index, and an
/// unrelated series lends its index as the length.
fn copy_part_count(
  cell : @value.Cell,
  source : @value.Cell,
) -> Int raise EvalError {
  match cell {
    @value.Integer(n) =>
      if n <= 0 {
        0
      } else if n > 2147483647L {
        2147483647
      } else {
        n.to_int()
      }
    @value.Seq(_, end_index) => {
      let start = match source {
        @value.Seq(_, source_index) => source_index
        _ => 0
      }
      if source.same(cell) && end_index >= start && end_index >= 0 {
        end_index - start
      } else if end_index < 0 {
        0
      } else if end_index > 2147483647 {
        2147483647
      } else {
        end_index
      }
    }
    _ => raise EvalError::Cannot("copy")
  }
}
