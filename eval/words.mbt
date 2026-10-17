///|
fn as_word(cell : @value.Cell, name : String) -> @value.Lexeme raise EvalError {
  match cell {
    @value.Sym(_, lexeme) => lexeme
    _ => raise EvalError::Cannot(name)
  }
}

///|
fn slot_value(env : Env, lexeme : @value.Lexeme) -> @value.Cell? {
  match lexeme.binding() {
    @value.Bound(frame, slot) => frame.get(slot)
    @value.Unbound =>
      match env.user.find(lexeme.sym()) {
        Some(slot) => env.user.get(slot)
        None => None
      }
  }
}

///|
fn write_word(
  env : Env,
  lexeme : @value.Lexeme,
  value : @value.Cell,
) -> Unit raise EvalError {
  match lexeme.binding() {
    @value.Bound(frame, slot) => store(frame, slot, value)
    @value.Unbound => {
      let slot = env.user.ensure(lexeme.sym())
      store(env.user, slot, value)
    }
  }
}

///|
fn store(
  frame : @value.Frame,
  slot : Int,
  value : @value.Cell,
) -> Unit raise EvalError {
  if frame.set(slot, value) {
    ()
  } else {
    raise EvalError::Cannot("protected")
  }
}

///|
fn perform_get(env : Env, word : @value.Cell) -> @value.Cell raise EvalError {
  let lexeme = as_word(word, "get")
  match slot_value(env, lexeme) {
    Some(value) =>
      if value is @value.Cell::Unset {
        raise EvalError::NoValue(lexeme.spelling())
      } else {
        value
      }
    None => raise EvalError::NoValue(lexeme.spelling())
  }
}

///|
fn perform_set(
  env : Env,
  word : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  write_word(env, as_word(word, "set"), value)
  value
}

///|
fn perform_unset(env : Env, word : @value.Cell) -> @value.Cell raise EvalError {
  write_word(env, as_word(word, "unset"), @value.Cell::Unset)
  @value.Cell::Unset
}

///|
fn perform_none_q(value : @value.Cell) -> @value.Cell {
  @value.Logic(value is @value.None)
}

///|
/// True for a block, paren, path, string, binary, or any-string series.
fn perform_series_q(value : @value.Cell) -> @value.Cell {
  let flag = match value {
    @value.Seq(series, _) =>
      match series.datatype() {
        @value.String
        | @value.File
        | @value.Email
        | @value.Url
        | @value.Tag
        | @value.Issue
        | @value.Binary
        | @value.Block
        | @value.Paren
        | @value.Path
        | @value.SetPath => true
        _ => false
      }
    _ => false
  }
  @value.Logic(flag)
}

///|
fn perform_value_q(
  env : Env,
  word : @value.Cell,
) -> @value.Cell raise EvalError {
  let lexeme = as_word(word, "value?")
  let set = match slot_value(env, lexeme) {
    Some(value) => !(value is @value.Cell::Unset)
    None => false
  }
  @value.Logic(set)
}

///|
fn perform_unset_q(
  env : Env,
  word : @value.Cell,
) -> @value.Cell raise EvalError {
  let lexeme = as_word(word, "unset?")
  let unset = match slot_value(env, lexeme) {
    Some(value) => value is @value.Cell::Unset
    None => true
  }
  @value.Logic(unset)
}

///|
fn perform_in(
  env : Env,
  object : @value.Cell,
  word : @value.Cell,
) -> @value.Cell raise EvalError {
  let _ = env
  match object {
    @value.Object(frame) => object_field(frame, as_word(word, "in"))
    _ => raise EvalError::Cannot("in")
  }
}

///|
fn context_frame(env : Env, cell : @value.Cell) -> @value.Frame raise EvalError {
  match cell {
    @value.Object(frame) => frame
    @value.Sym(_, lexeme) =>
      match lexeme.binding() {
        @value.Bound(frame, _) => frame
        @value.Unbound =>
          match env.user.find(lexeme.sym()) {
            Some(_) => env.user
            None => raise EvalError::Cannot("bind")
          }
      }
    _ => raise EvalError::Cannot("bind")
  }
}

///|
fn perform_bind(
  env : Env,
  target : @value.Cell,
  context : @value.Cell,
) -> @value.Cell raise EvalError {
  @bind.bind(target, context_frame(env, context))
}

///|
fn perform_unbind(cell : @value.Cell) -> @value.Cell {
  @bind.unbind(cell)
}
