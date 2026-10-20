///|
fn perform_remove(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut part : @value.Cell? = None
  let mut slot = 1
  for sym in active {
    match env.symbols.canon(sym) {
      "part" => {
        if slot >= args.length() {
          raise EvalError::MissingArg("argument")
        }
        part = Some(args[slot])
        slot = slot + 1
      }
      _ => raise EvalError::Cannot("remove")
    }
  }
  match part {
    Some(@value.Integer(n)) => {
      let count = if n <= 0L {
        0
      } else if n > 2147483647L {
        2147483647
      } else {
        n.to_int()
      }
      from_action(@action.remove_part(args[0], count))
    }
    Some(_) => raise EvalError::Cannot("remove")
    None => from_action(@action.remove(args[0]))
  }
}
