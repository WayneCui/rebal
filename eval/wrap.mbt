///|
/// Evaluates a block with set-words local to that evaluation.
/// A word is local only after its set-word has been seen, so a use before
/// the set-word still reads the outer value. `launch`, `any-of`, and
/// `all-of` stay out.
fn perform_wrap(env : Env, body : @value.Cell) -> @value.Cell raise EvalError {
  match body {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let copied = series.copy_deep(index)
      let frame = @value.Frame::new()
      bind_after_set(copied, 0, frame, [])
      eval(env, @value.Seq(copied, 0))
    }
    _ => raise EvalError::Cannot("wrap")
  }
}

///|
fn bind_after_set(
  series : @value.Series,
  index : Int,
  frame : @value.Frame,
  stack : Array[@value.Series],
) -> Unit {
  if is_bindable(series) && !seen_series(stack, series) {
    stack.push(series)
    let mut cursor = if index < 0 { 0 } else { index }
    while cursor < series.length() {
      match series.item(cursor) {
        Some(@value.Sym(datatype, lexeme)) => {
          if datatype is @value.SetWord {
            frame.ensure(lexeme.sym()) |> ignore
          }
          match frame.find(lexeme.sym()) {
            Some(slot) =>
              if is_any_word(datatype) {
                series.set_item(
                  cursor,
                  @value.Sym(
                    datatype,
                    lexeme.with_binding(@value.Bound(frame, slot)),
                  ),
                )
                |> ignore
              }
            None => ()
          }
        }
        Some(@value.Seq(nested, nested_index)) =>
          bind_after_set(nested, nested_index, frame, stack)
        _ => ()
      }
      cursor = cursor + 1
    }
    stack.remove(stack.length() - 1) |> ignore
  }
}

///|
fn is_bindable(series : @value.Series) -> Bool {
  let datatype = series.datatype()
  datatype == @value.Block ||
  datatype == @value.Paren ||
  datatype == @value.Path ||
  datatype == @value.SetPath
}

///|
fn is_any_word(datatype : @value.Datatype) -> Bool {
  datatype is @value.Word ||
  datatype is @value.SetWord ||
  datatype is @value.GetWord ||
  datatype is @value.LitWord ||
  datatype is @value.Refinement
}

///|
fn seen_series(stack : Array[@value.Series], series : @value.Series) -> Bool {
  let mut index = 0
  let mut found = false
  while index < stack.length() && !found {
    if physical_equal(stack[index], series) {
      found = true
    }
    index = index + 1
  }
  found
}
