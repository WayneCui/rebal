///|
/// How many value arguments the active `append` refinements contribute.
/// `/only` and `/line` take none; `/part` and `/dup` take one each.
fn append_extra(env : Env, active : Array[Int]) -> Int raise EvalError {
  let mut extra = 0
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "part" || name == "dup" {
      extra = extra + 1
    } else if name != "only" && name != "line" {
      raise EvalError::Cannot("append")
    }
  }
  extra
}

///|
/// `append` adds a value at the tail. `/only` appends a block as one item
/// instead of splicing its items in. `/part` bounds how much of a series
/// value is taken; `/dup` repeats the value.
fn perform_append(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut only = false
  let mut part : @value.Cell? = None
  let mut dup = 1
  let mut slot = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "only" {
      only = true
    } else if name == "line" {
      raise EvalError::Cannot("append")
    } else if name == "part" {
      part = Some(args[slot])
      slot = slot + 1
    } else if name == "dup" {
      dup = match args[slot] {
        @value.Integer(n) if n >= 1L && n <= 2147483647L => n.to_int()
        _ => raise EvalError::Cannot("append")
      }
      slot = slot + 1
    }
  }
  let mut value = args[1]
  match part {
    Some(cell) =>
      match value {
        @value.Seq(vseries, vindex) => {
          let count = copy_part_count(cell, value)
          value = @value.Seq(vseries.copy_span(vindex, count), 0)
        }
        _ => ()
      }
    None => ()
  }
  match args[0] {
    @value.Seq(series, index) => {
      let item_datatype = match series.datatype() {
        @value.Block | @value.Paren | @value.Path | @value.SetPath => true
        _ => false
      }
      if only && item_datatype {
        let mut repeat = 0
        while repeat < dup {
          series.push_item(value) |> ignore
          repeat = repeat + 1
        }
        @value.Seq(series, index)
      } else {
        let mut repeat = 0
        let mut ok = true
        while ok && repeat < dup {
          match @action.append(@value.Seq(series, index), value) {
            Ok(_) => repeat = repeat + 1
            Err(_) => ok = false
          }
        }
        if ok {
          @value.Seq(series, index)
        } else {
          raise EvalError::Cannot("append")
        }
      }
    }
    _ => raise EvalError::Cannot("append")
  }
}
