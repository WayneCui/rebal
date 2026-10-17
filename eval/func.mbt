///|
/// Copies `body` and binds parameter words onto a fresh frame.
/// Words that are not parameters keep the binding they already have.
fn build_func(
  spec : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let names = spec_names(spec)
  let frame = @value.Frame::new()
  for sym in names.0 {
    frame.ensure(sym) |> ignore
  }
  for sym in names.1 {
    frame.ensure(sym) |> ignore
  }
  match copied_block(body) {
    Some(series) => {
      @bind.bind(@value.Seq(series, 0), frame) |> ignore
      @value.Function(@value.Func::make(names.0, series, false, frame))
    }
    None => raise EvalError::Cannot("func")
  }
}

///|
/// Words before `/local` are arguments. Words after it are locals.
fn spec_names(spec : @value.Cell) -> (Array[Int], Array[Int]) raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let args : Array[Int] = []
      let locals : Array[Int] = []
      let mut cursor = index
      let mut after_mark = false
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.Word, lexeme)) =>
            if after_mark {
              locals.push(lexeme.sym())
            } else {
              args.push(lexeme.sym())
            }
          Some(@value.Sym(@value.Refinement, lexeme)) =>
            if lexeme.spelling() == "local" {
              after_mark = true
            } else {
              raise EvalError::Cannot("func")
            }
          _ => raise EvalError::Cannot("func")
        }
        cursor = cursor + 1
      }
      (args, locals)
    }
    _ => raise EvalError::Cannot("func")
  }
}

///|
fn copied_block(cell : @value.Cell) -> @value.Series? {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      Some(series.copy_from(index))
    _ => None
  }
}

///|
/// Writes arguments into the function frame, then evaluates its body.
fn call_user(
  env : Env,
  func : @value.Func,
  args : Array[@value.Cell],
) -> @value.Cell raise EvalError {
  let frame = func.frame()
  let names = func.params()
  let mut index = 0
  while index < names.length() {
    match frame.find(names[index]) {
      Some(slot) => frame.set(slot, args[index])
      None => raise EvalError::Cannot("func")
    }
    index = index + 1
  }
  do_series(env, func.body(), 0) catch {
    EvalError::Returned(cell) => cell
    error => raise error
  }
}

///|
fn invoke(env : Env, func : @value.Func) -> @value.Cell raise EvalError {
  if func.arity() != 0 {
    raise EvalError::MissingArg("argument")
  } else if func.code() == 0 {
    call_user(env, func, [])
  } else {
    apply(env, func, [])
  }
}

///|
/// `do` of a word fetches it. A function is called. A fetched block is not.
fn perform_do(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Sym(_, lexeme) => {
      let value = lookup_word(env, lexeme)
      match value {
        @value.Function(func) => invoke(env, func)
        _ => value
      }
    }
    @value.Function(func) => invoke(env, func)
    @value.Seq(series, _) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren ||
      series.datatype() == @value.String => eval(env, cell)
    _ => cell
  }
}

///|
fn lookup_word(
  env : Env,
  lexeme : @value.Lexeme,
) -> @value.Cell raise EvalError {
  match lexeme.binding() {
    @value.Bound(frame, slot) => defined(frame, slot, lexeme.spelling())
    @value.Unbound =>
      match env.user.find(lexeme.sym()) {
        Some(slot) => defined(env.user, slot, lexeme.spelling())
        None => raise EvalError::NoValue(lexeme.spelling())
      }
  }
}

///|
/// Evaluates a block. A failure inside it comes back as `error!`.
/// `return` is not a failure and keeps traveling to the function that called it.
fn perform_try(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, _) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren =>
      eval(env, cell) catch {
        EvalError::Returned(value) => raise EvalError::Returned(value)
        EvalError::Broken => raise EvalError::Broken
        EvalError::Continued => raise EvalError::Continued
        error => error.to_cell()
      }
    _ => cell
  }
}

///|
/// Evaluates each expression. Unset results are left out. `none` stays `none`.
fn reduce_block(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.None => @value.None
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => {
      let out = @value.Series::block()
      let mut cursor = index
      while cursor < series.length() {
        let stepped = do_next_at(env, series, cursor)
        if stepped.1 <= cursor {
          raise EvalError::Cannot("reduce")
        }
        match stepped.0 {
          @value.Unset => ()
          value => out.push_item(value) |> ignore
        }
        cursor = stepped.1
      }
      @value.Seq(out, 0)
    }
    _ => raise EvalError::Cannot("reduce")
  }
}
