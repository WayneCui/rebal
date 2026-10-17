///|
fn perform_enhex(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let (plus, escape) = enhex_flags(env, args, active)
  from_action(@action.enhex_with(args[0], plus, escape))
}

///|
fn enhex_flags(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> (Bool, Int) raise EvalError {
  let mut plus = false
  let mut escape = '%'.to_int()
  let mut cursor = 1
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "uri" {
      plus = true
    } else if name == "escape" {
      escape = enhex_mark(args[cursor])
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("enhex")
    }
  }
  (plus, escape)
}

///|
fn enhex_mark(cell : @value.Cell) -> Int raise EvalError {
  match cell {
    @value.Char(code) => code
    _ => raise EvalError::Cannot("enhex")
  }
}
