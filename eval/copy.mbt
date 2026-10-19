///|
/// `copy` takes `/deep` to copy nested series as well. A map is cloned
/// either way; its values stay shared.
fn perform_copy(
  env : Env,
  value : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut deep = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "deep" {
      deep = true
    } else {
      raise EvalError::Cannot("copy")
    }
  }
  if deep {
    match value {
      @value.Seq(series, index) => @value.Seq(series.copy_deep(index), 0)
      @value.Map(map) => @value.Map(map.copy())
      _ => from_action(@action.copy(value))
    }
  } else {
    from_action(@action.copy(value))
  }
}
