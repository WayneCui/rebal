///|
fn make_value(
  env : Env,
  datatype : @value.Cell,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  match datatype {
    @value.Type(@value.Object) => make_object(env, spec)
    @value.Type(@value.Op) => make_op(spec)
    @value.Type(@value.Percent) => to_percent(spec, true)
    @value.Type(@value.Decimal) => decimal_from(spec)
    @value.Type(@value.Integer) => integer_from(spec)
    @value.Type(@value.Pair) => to_pair(spec)
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
