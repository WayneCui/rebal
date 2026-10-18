///|
fn perform_find(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut last = false
  let mut reverse = false
  let mut match_only = false
  let mut tail = false
  let mut only = false
  let mut part = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "last" {
      last = true
    } else if name == "reverse" {
      reverse = true
    } else if name == "match" {
      match_only = true
    } else if name == "tail" {
      tail = true
    } else if name == "only" {
      only = true
    } else if name == "part" {
      part = true
    } else {
      raise EvalError::Cannot("find")
    }
  }
  let limit = if part {
    match args[2] {
      @value.Integer(n) =>
        if n < 0L {
          raise EvalError::Cannot("find")
        } else {
          Some(n.to_int())
        }
      _ => raise EvalError::Cannot("find")
    }
  } else {
    None
  }
  match args[0] {
    @value.Typeset(types) =>
      if last || reverse || match_only || tail || only || part {
        raise EvalError::Cannot("find")
      } else {
        typeset_find(types, args[1])
      }
    _ =>
      from_action(
        @action.seek(
          args[0],
          args[1],
          last,
          reverse,
          match_only,
          tail,
          only,
          limit,
        ),
      )
  }
}
