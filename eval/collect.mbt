///|
/// The buffers `collect` fills. A nested collect starts a fresh buffer, and
/// `keep` always lands in the innermost one.
priv struct CollectGather {
  buffers : Array[Array[@value.Cell]]
  only : Array[Bool]
}

///|
let collect_gather : CollectGather = { buffers: [], only: [], }

///|
/// Evaluates the block and returns what `keep` collected. With `/only`,
/// every kept value stays a single item, the way `keep/only` asks for.
fn perform_collect(
  env : Env,
  cell : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut only = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "only" {
      only = true
    } else {
      raise EvalError::Cannot("collect")
    }
  }
  match cell {
    @value.Seq(series, _) if series.datatype() == @value.Block => {
      let buffer : Array[@value.Cell] = []
      collect_gather.buffers.push(buffer)
      collect_gather.only.push(only)
      errdefer {
        collect_gather.buffers.pop() |> ignore
        collect_gather.only.pop() |> ignore
      }
      eval(env, cell) |> ignore
      collect_gather.buffers.pop() |> ignore
      collect_gather.only.pop() |> ignore
      let out = @value.Series::block()
      for item in buffer {
        out.push_item(item) |> ignore
      }
      @value.Seq(out, 0)
    }
    _ => raise EvalError::Cannot("collect")
  }
}

///|
/// Adds one value to the innermost `collect`. A block is spliced unless the
/// call says `/only`, or the enclosing collect does.
fn perform_keep(
  env : Env,
  value : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  if collect_gather.buffers.length() == 0 {
    raise EvalError::Cannot("keep")
  }
  let mut only = collect_gather.only[collect_gather.only.length() - 1]
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "only" {
      only = true
    } else {
      raise EvalError::Cannot("keep")
    }
  }
  let buffer = collect_gather.buffers[collect_gather.buffers.length() - 1]
  if only {
    buffer.push(value)
  } else {
    match value {
      @value.Seq(series, index) if series.datatype() == @value.Block => {
        let mut cursor = if index < 0 { 0 } else { index }
        while cursor < series.length() {
          match series.item(cursor) {
            Some(item) => buffer.push(item.snapshot())
            None => ()
          }
          cursor = cursor + 1
        }
      }
      other => buffer.push(other)
    }
  }
  value
}
