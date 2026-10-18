///|
fn make_value(
  env : Env,
  datatype : @value.Cell,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  match datatype {
    @value.Type(@value.Object) => make_object(env, spec)
    @value.Type(@value.Port) => make_port(env, spec)
    @value.Type(@value.Op) => make_op(spec)
    @value.Type(@value.Percent) => to_percent(spec, true)
    @value.Type(@value.Decimal) => decimal_from(spec)
    @value.Type(@value.Integer) => integer_from(spec)
    @value.Type(@value.Pair) => to_pair(spec)
    @value.Type(@value.Tuple) => to_tuple(spec)
    @value.Type(@value.Money) => to_money(spec)
    @value.Type(@value.Time) => to_time(spec)
    @value.Type(@value.Date) => to_date(spec)
    @value.Type(@value.Bitset) => to_bitset(spec)
    @value.Type(@value.Map) => to_map(spec)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn make_op(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Function(func) => @value.Function(func.as_op())
    _ => raise EvalError::Cannot("make")
  }
}

///|
/// Collects top-level set-words, binds the spec to that frame, then evaluates it.
fn make_object(env : Env, spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let frame = @value.Frame::new()
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.SetWord, lexeme)) =>
            frame.ensure(lexeme.sym()) |> ignore
          _ => ()
        }
        cursor = cursor + 1
      }
      @bind.bind(@value.Seq(series, index), frame) |> ignore
      do_series(env, series, index) |> ignore
      @value.Object(frame)
    }
    _ => raise EvalError::Cannot("make")
  }
}

///|
/// Words of an object, in creation order. Map keys that are words become words.
fn words_of(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let block = @value.Series::block()
  match value {
    @value.Object(frame) =>
      for index in 0..<frame.length() {
        match frame.sym(index) {
          Some(sym) =>
            block.push_item(word_cell(env, env.symbols.canon(sym))) |> ignore
          None => ()
        }
      }
    @value.Map(map) =>
      for index in 0..<map.length() {
        match map.key(index) {
          Some(key) => block.push_item(word_key(key)) |> ignore
          None => ()
        }
      }
    @value.Function(func) =>
      for index in 0..<func.spec_words().length() {
        let sym = func.spec_words()[index]
        let kind = func.spec_kinds()[index]
        block.push_item(func_spec_word(env, sym, kind)) |> ignore
      }
    _ => raise EvalError::Caused("expect-arg", "words-of")
  }
  @value.Seq(block, 0)
}

///|
fn func_spec_word(env : Env, sym : Int, kind : Int) -> @value.Cell {
  let spelling = env.symbols.canon(sym)
  let lexeme = @value.Lexeme::make(sym, spelling)
  let datatype = if kind == 1 {
    @value.Refinement
  } else if kind == 2 {
    @value.LitWord
  } else {
    @value.Word
  }
  @value.Sym(datatype, lexeme)
}

///|
fn word_key(key : @value.Cell) -> @value.Cell {
  match key {
    @value.Sym(_, lexeme) => @value.Sym(@value.Word, lexeme)
    _ => key
  }
}
