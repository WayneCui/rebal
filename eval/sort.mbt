///|
fn perform_sort(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut reverse = false
  let mut skip = false
  for sym in active {
    match env.symbols.canon(sym) {
      "reverse" => reverse = true
      "skip" => skip = true
      _ => raise EvalError::Cannot("sort")
    }
  }
  if skip {
    if args.length() < 2 {
      raise EvalError::MissingArg("argument")
    }
    let size = match args[1] {
      @value.Integer(n) =>
        if n <= 0L {
          raise EvalError::Cannot("sort")
        } else {
          n.to_int()
        }
      _ => raise EvalError::Cannot("sort")
    }
    from_action(@action.sort_skip(args[0], size, reverse))
  } else {
    from_action(@action.sort(args[0], reverse))
  }
}
