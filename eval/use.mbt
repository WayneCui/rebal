///|
/// `use` evaluates the body with the named words local to that evaluation.
/// Each local starts as `none`. The caller's block is left unchanged.
fn perform_use(
  env : Env,
  vars : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let words = use_words(vars)
  let spec = @value.Series::block()
  for word in words {
    spec.push_item(word) |> ignore
  }
  let source = match body {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      @value.Seq(series.copy_deep(index), 0)
    _ => raise EvalError::Cannot("use")
  }
  match build_func(env, @value.Seq(spec, 0), source, true) {
    @value.Function(func) => {
      let args : Array[@value.Cell] = []
      for word in words {
        let _ = word
        args.push(@value.None)
      }
      call_user(env, func, args, [])
    }
    _ => raise EvalError::Cannot("use")
  }
}

///|
fn use_words(vars : @value.Cell) -> Array[@value.Cell] raise EvalError {
  match vars {
    @value.Sym(@value.Word, lexeme)
    | @value.Sym(@value.LitWord, lexeme)
    | @value.Sym(@value.SetWord, lexeme) => [word_from(lexeme)]
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let words : Array[@value.Cell] = []
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.Word, lexeme)) => words.push(word_from(lexeme))
          _ => raise EvalError::Cannot("use")
        }
        cursor = cursor + 1
      }
      words
    }
    _ => raise EvalError::Cannot("use")
  }
}

///|
fn word_from(lexeme : @value.Lexeme) -> @value.Cell {
  @value.Sym(@value.Word, @value.Lexeme::make(lexeme.sym(), lexeme.spelling()))
}
