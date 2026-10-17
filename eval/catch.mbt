///|
fn throw_name(cell : @value.Cell) -> String raise EvalError {
  match cell {
    @value.None => ""
    @value.Sym(_, lexeme) => lexeme.spelling()
    _ => raise EvalError::Cannot("throw")
  }
}

///|
/// Evaluates the block. A matching `throw` becomes the result.
fn perform_catch(
  env : Env,
  name : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let expected = throw_name(name)
  eval_block(env, body, "catch") catch {
    EvalError::Thrown(got, value) =>
      if got == expected {
        value
      } else {
        raise EvalError::Thrown(got, value)
      }
    error => raise error
  }
}

///|
fn perform_throw(
  name : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  raise EvalError::Thrown(throw_name(name), value)
}
