///|
fn perform_dehex(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let (escape, uri) = dehex_flags(env, args, active)
  from_action(@action.dehex_with(args[0], escape, uri))
}

///|
fn dehex_flags(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> (Int, Bool) raise EvalError {
  let mut escape = '%'.to_int()
  let mut uri = false
  let mut cursor = 1
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "uri" {
      uri = true
    } else if name == "escape" {
      escape = dehex_mark(args[cursor])
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("dehex")
    }
  }
  (escape, uri)
}

///|
fn dehex_mark(cell : @value.Cell) -> Int raise EvalError {
  match cell {
    @value.Char(code) => code
    _ => raise EvalError::Cannot("dehex")
  }
}
