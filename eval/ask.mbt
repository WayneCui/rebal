///|
/// Reads one console line. A queued line is used first, so tests do not
/// wait on the terminal. End of input is `none`. `/hide` stays out.
fn perform_input() -> @value.Cell raise EvalError {
  match next_console_line() {
    Some(text) => text_series(text)
    None => @value.None
  }
}

///|
/// Prints a question and reads the answer. `/hide` and `/only` stay out.
fn perform_ask(question : @value.Cell) -> @value.Cell raise EvalError {
  match question {
    @value.Seq(_) => {
      emit_console(@mold.form_text(question))
      perform_input()
    }
    _ => raise EvalError::Cannot("ask")
  }
}
