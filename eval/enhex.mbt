///|
/// Encodes a string, file, url, or binary. `/uri` writes a space as `+` and encodes a plus sign.
fn perform_enhex(
  env : Env,
  value : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let plus = enhex_plus(env, active)
  if plus {
    from_action(@action.enhex_uri(value))
  } else {
    from_action(@action.enhex(value))
  }
}

///|
fn enhex_plus(env : Env, active : Array[Int]) -> Bool raise EvalError {
  let mut plus = false
  for sym in active {
    if env.symbols.canon(sym) == "uri" {
      plus = true
    } else {
      raise EvalError::Cannot("enhex")
    }
  }
  plus
}
