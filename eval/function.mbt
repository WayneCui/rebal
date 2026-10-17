///|
/// `function` adds set-words from the body as locals. Words already named in
/// the spec stay as they are. `/with` and `/extern` are not accepted yet.
fn perform_function(
  env : Env,
  spec : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let known = spec_words(series, index)
      let locals = body_locals(body, known)
      build_func(
        env,
        @value.Seq(extend_spec(env, series, index, locals), 0),
        body,
        false,
      )
    }
    _ => raise EvalError::Cannot("func")
  }
}

///|
fn spec_words(series : @value.Series, index : Int) -> Array[Int] {
  let words : Array[Int] = []
  let mut cursor = index
  while cursor < series.length() {
    match series.item(cursor) {
      Some(@value.Sym(@value.Word, lexeme))
      | Some(@value.Sym(@value.Refinement, lexeme)) => words.push(lexeme.sym())
      _ => ()
    }
    cursor = cursor + 1
  }
  words
}

///|
fn body_locals(body : @value.Cell, known : Array[Int]) -> Array[Int] {
  let locals : Array[Int] = []
  gather_sets(body, known, locals)
  locals
}

///|
fn gather_sets(
  cell : @value.Cell,
  known : Array[Int],
  locals : Array[Int],
) -> Unit {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => {
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.SetWord, lexeme)) =>
            if !listed(known, lexeme.sym()) && !listed(locals, lexeme.sym()) {
              locals.push(lexeme.sym())
            }
          Some(item) => gather_sets(item, known, locals)
          None => ()
        }
        cursor = cursor + 1
      }
    }
    _ => ()
  }
}

///|
fn listed(words : Array[Int], sym : Int) -> Bool {
  let mut index = 0
  let mut found = false
  while index < words.length() && !found {
    if words[index] == sym {
      found = true
    }
    index = index + 1
  }
  found
}

///|
fn extend_spec(
  env : Env,
  series : @value.Series,
  index : Int,
  locals : Array[Int],
) -> @value.Series {
  let out = @value.Series::block()
  let mut cursor = index
  let mut placed = false
  while cursor < series.length() {
    match series.item(cursor) {
      Some(item) => {
        out.push_item(item) |> ignore
        if is_local_refine(item) {
          push_locals(env, out, locals)
          placed = true
        }
      }
      None => ()
    }
    cursor = cursor + 1
  }
  if !placed && locals.length() > 0 {
    out.push_item(local_refine(env)) |> ignore
    push_locals(env, out, locals)
  }
  out
}

///|
fn push_locals(env : Env, series : @value.Series, locals : Array[Int]) -> Unit {
  for sym in locals {
    let spelling = env.symbols.canon(sym)
    series.push_item(
      @value.Sym(@value.Word, @value.Lexeme::make(sym, spelling)),
    )
    |> ignore
  }
}

///|
fn is_local_refine(cell : @value.Cell) -> Bool {
  match cell {
    @value.Sym(@value.Refinement, lexeme) => lexeme.spelling() == "local"
    _ => false
  }
}

///|
fn local_refine(env : Env) -> @value.Cell {
  let sym = env.symbols.intern("local")
  @value.Sym(@value.Refinement, @value.Lexeme::make(sym, "local"))
}
