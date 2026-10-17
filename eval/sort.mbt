///|
fn perform_sort(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut reverse = false
  for sym in active {
    if env.symbols.canon(sym) == "reverse" {
      reverse = true
    } else {
      raise EvalError::Cannot("sort")
    }
  }
  from_action(@action.sort(args[0], reverse))
}
