///|
/// Evaluates a source string in the user frame.
/// A `return` with no function around it becomes an error.
pub fn run(env : Env, source : String) -> @value.Cell raise EvalError {
  eval(env, load(env, source)) catch {
    EvalError::Returned(_) => raise EvalError::NoReturn
    error => raise error
  }
}

///|
/// Evaluates a block, paren, or string. Other values are returned as they are.
pub fn eval(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, index) =>
      match series.datatype() {
        @value.String => eval(env, load(env, text_from(series, index)))
        @value.Block | @value.Paren => do_series(env, series, index)
        _ => cell
      }
    _ => cell
  }
}

///|
/// Evaluates one expression. The remainder shares the input series.
/// A non-series input returns that value and `none`.
pub fn do_next(
  env : Env,
  cell : @value.Cell,
) -> (@value.Cell, @value.Cell) raise EvalError {
  match cell {
    @value.Seq(series, index) =>
      match series.datatype() {
        @value.String => do_next(env, load(env, text_from(series, index)))
        @value.Block | @value.Paren => {
          let (value, next) = do_next_at(env, series, index)
          (value, @value.Seq(series, next))
        }
        _ => (cell, @value.None)
      }
    _ => (cell, @value.None)
  }
}

///|
fn text_from(series : @value.Series, index : Int) -> String raise EvalError {
  let buf = StringBuilder()
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.code(cursor) {
      Some(code) =>
        match code.to_char() {
          Some(char) => buf.write_char(char)
          None => raise EvalError::BadSource("char")
        }
      None => ()
    }
    cursor = cursor + 1
  }
  buf.to_string()
}

///|
fn do_series(
  env : Env,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let mut cursor = index
  let mut result = @value.Cell::Unset
  while cursor < series.length() {
    let (value, next) = do_next_at(env, series, cursor)
    if next <= cursor {
      raise EvalError::Cannot("eval")
    }
    result = value
    cursor = next
  }
  result
}

///|
fn do_next_at(
  env : Env,
  series : @value.Series,
  index : Int,
) -> (@value.Cell, Int) raise EvalError {
  if index >= series.length() {
    (@value.Unset, index)
  } else {
    let started = eval_atom(env, series, index)
    let mut value = started.0
    let mut cursor = started.1
    let mut running = true
    while running {
      match infix_at(env, series, cursor) {
        Some(func) =>
          if cursor + 1 >= series.length() {
            raise EvalError::MissingArg("op")
          } else {
            let right = eval_atom(env, series, cursor + 1)
            if right.1 <= cursor {
              raise EvalError::Cannot("eval")
            }
            value = apply(env, func, [value, right.0])
            cursor = right.1
          }
        None => running = false
      }
    }
    (value, cursor)
  }
}

///|
fn eval_atom(
  env : Env,
  series : @value.Series,
  index : Int,
) -> (@value.Cell, Int) raise EvalError {
  match series.item(index) {
    None => (@value.Unset, index)
    Some(@value.Sym(@value.SetWord, lexeme)) => {
      if index + 1 >= series.length() {
        raise EvalError::MissingArg(lexeme.spelling())
      }
      let (value, next) = do_next_at(env, series, index + 1)
      assign(env, series, index, lexeme, value)
      (value, next)
    }
    Some(@value.Sym(@value.GetWord, lexeme)) =>
      (fetch(env, series, index, @value.GetWord, lexeme), index + 1)
    Some(@value.Sym(@value.LitWord, lexeme)) =>
      (
        @value.Sym(
          @value.Word,
          @value.Lexeme::make(lexeme.sym(), lexeme.spelling()),
        ),
        index + 1,
      )
    Some(@value.Function(func)) =>
      if func.is_infix() {
        raise EvalError::OpArg("op")
      } else {
        call(env, series, index + 1, func)
      }
    Some(@value.Seq(nested, nested_index)) if is_set_path(nested) => {
      if index + 1 >= series.length() {
        raise EvalError::MissingArg("path")
      }
      let (value, next) = do_next_at(env, series, index + 1)
      path_set(env, nested, nested_index, value) |> ignore
      (value, next)
    }
    Some(@value.Seq(nested, nested_index)) if nested.datatype() == @value.Path => {
      let value = path_get(env, nested, nested_index)
      match value {
        @value.Function(func) if !func.is_infix() =>
          call(env, series, index + 1, func)
        _ => (value, index + 1)
      }
    }
    Some(@value.Sym(@value.Word, lexeme)) => {
      let value = fetch(env, series, index, @value.Word, lexeme)
      match value {
        @value.Function(func) =>
          if func.is_infix() {
            raise EvalError::OpArg(lexeme.spelling())
          } else {
            call(env, series, index + 1, func)
          }
        _ => (value, index + 1)
      }
    }
    Some(@value.Seq(nested, nested_index)) =>
      if nested.datatype() == @value.Paren {
        (do_series(env, nested, nested_index), index + 1)
      } else {
        (series.item(index).unwrap(), index + 1)
      }
    Some(cell) => (cell, index + 1)
  }
}

///|
fn call(
  env : Env,
  series : @value.Series,
  index : Int,
  func : @value.Func,
) -> (@value.Cell, Int) raise EvalError {
  let args : Array[@value.Cell] = []
  let mut cursor = index
  for _ in 0..<func.arity() {
    if cursor >= series.length() {
      raise EvalError::MissingArg("argument")
    }
    let (arg, next) = do_next_at(env, series, cursor)
    args.push(arg)
    cursor = next
  }
  (apply(env, func, args), cursor)
}

///|
fn apply(
  env : Env,
  func : @value.Func,
  args : Array[@value.Cell],
) -> @value.Cell raise EvalError {
  if func.code() == 0 {
    call_user(env, func, args)
  } else if func.code() == native_add {
    from_action(@action.add(args[0], args[1]))
  } else if func.code() == native_subtract {
    from_action(@action.subtract(args[0], args[1]))
  } else if func.code() == native_multiply {
    from_action(@action.multiply(args[0], args[1]))
  } else if func.code() == native_append {
    from_action(@action.append(args[0], args[1]))
  } else if func.code() == native_find {
    from_action(@action.find(args[0], args[1]))
  } else if func.code() == native_pick {
    from_action(@action.pick(args[0], args[1]))
  } else if func.code() == native_length {
    from_action(@action.length(args[0]))
  } else if func.code() == native_first {
    from_action(@action.first(args[0]))
  } else if func.code() == native_copy {
    from_action(@action.copy(args[0]))
  } else if func.code() == native_insert {
    from_action(@action.insert(args[0], args[1]))
  } else if func.code() == native_remove {
    from_action(@action.remove(args[0]))
  } else if func.code() == native_func {
    build_func(args[0], args[1])
  } else if func.code() == native_does {
    build_func(@value.Seq(@value.Series::block(), 0), args[0])
  } else if func.code() == native_make {
    make_value(env, args[0], args[1])
  } else if func.code() == native_reduce {
    reduce_block(env, args[0])
  } else if func.code() == native_do {
    perform_do(env, args[0])
  } else if func.code() == native_mold {
    from_action(@action.mold(args[0]))
  } else if func.code() == native_form {
    from_action(@action.form(args[0]))
  } else if func.code() == native_type {
    @value.Type(args[0].datatype())
  } else if func.code() == native_try {
    perform_try(env, args[0])
  } else if func.code() == native_equal {
    @value.Logic(@action.equal(args[0], args[1]))
  } else if func.code() == native_not_equal {
    @value.Logic(!@action.equal(args[0], args[1]))
  } else if func.code() == native_lesser {
    logic_order(@action.lesser(args[0], args[1]))
  } else if func.code() == native_greater {
    logic_order(@action.greater(args[0], args[1]))
  } else if func.code() == native_if {
    perform_if(env, args[0], args[1])
  } else if func.code() == native_either {
    perform_either(env, args[0], args[1], args[2])
  } else if func.code() == native_return {
    raise EvalError::Returned(args[0])
  } else {
    raise EvalError::Cannot("function")
  }
}

///|
fn logic_order(
  result : Result[Bool, @action.ActionError],
) -> @value.Cell raise EvalError {
  match result {
    Ok(flag) => @value.Logic(flag)
    Err(_) => raise EvalError::Cannot("compare")
  }
}

///|
fn from_action(
  result : Result[@value.Cell, @action.ActionError],
) -> @value.Cell raise EvalError {
  match result {
    Ok(cell) => cell
    Err(error) => raise EvalError::Cannot(error.id())
  }
}

///|
fn infix_at(env : Env, series : @value.Series, index : Int) -> @value.Func? {
  if index >= series.length() {
    None
  } else {
    match series.item(index) {
      Some(@value.Sym(@value.Word, lexeme)) =>
        match quiet(env, lexeme) {
          Some(@value.Function(func)) if func.is_infix() => Some(func)
          _ => None
        }
      _ => None
    }
  }
}

///|
fn fetch(
  env : Env,
  series : @value.Series,
  index : Int,
  datatype : @value.Datatype,
  lexeme : @value.Lexeme,
) -> @value.Cell raise EvalError {
  match lexeme.binding() {
    @value.Bound(frame, slot) => defined(frame, slot, lexeme.spelling())
    @value.Unbound =>
      match env.user.find(lexeme.sym()) {
        Some(slot) => {
          series.set_item(
            index,
            @value.Sym(
              datatype,
              lexeme.with_binding(@value.Bound(env.user, slot)),
            ),
          )
          |> ignore
          defined(env.user, slot, lexeme.spelling())
        }
        None => raise EvalError::NoValue(lexeme.spelling())
      }
  }
}

///|
fn quiet(env : Env, lexeme : @value.Lexeme) -> @value.Cell? {
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
fn defined(
  frame : @value.Frame,
  slot : Int,
  spelling : String,
) -> @value.Cell raise EvalError {
  match frame.get(slot) {
    Some(cell) =>
      match cell {
        @value.Unset => raise EvalError::NoValue(spelling)
        _ => cell
      }
    None => raise EvalError::NoValue(spelling)
  }
}

///|
fn assign(
  env : Env,
  series : @value.Series,
  index : Int,
  lexeme : @value.Lexeme,
  value : @value.Cell,
) -> Unit {
  match lexeme.binding() {
    @value.Bound(frame, slot) => frame.set(slot, value)
    @value.Unbound => {
      let slot = env.user.ensure(lexeme.sym())
      series.set_item(
        index,
        @value.Sym(
          @value.SetWord,
          lexeme.with_binding(@value.Bound(env.user, slot)),
        ),
      )
      |> ignore
      env.user.set(slot, value)
    }
  }
}
