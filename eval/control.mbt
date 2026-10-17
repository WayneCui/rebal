///|
/// `false` and `none` skip a branch. Every other value takes it.
fn is_false(cell : @value.Cell) -> Bool {
  match cell {
    @value.Logic(false) => true
    @value.None => true
    _ => false
  }
}

///|
/// A block is evaluated. Any other branch value is returned as data.
fn eval_branch(env : Env, branch : @value.Cell) -> @value.Cell raise EvalError {
  match branch {
    @value.Seq(series, _) if series.datatype() == @value.Block =>
      eval(env, branch)
    _ => branch
  }
}

///|
/// When the condition is false, the result is `none` and the branch is left alone.
fn perform_if(
  env : Env,
  condition : @value.Cell,
  branch : @value.Cell,
) -> @value.Cell raise EvalError {
  if is_false(condition) {
    @value.None
  } else {
    eval_branch(env, branch)
  }
}

///|
/// Evaluates the chosen side. A non-block side is returned as data.
fn perform_either(
  env : Env,
  condition : @value.Cell,
  yes : @value.Cell,
  no : @value.Cell,
) -> @value.Cell raise EvalError {
  if is_false(condition) {
    eval_branch(env, no)
  } else {
    eval_branch(env, yes)
  }
}
