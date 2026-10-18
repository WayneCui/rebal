///|
/// What the session does with one finished line. `Halt` ends the process
/// and prints nothing. `Keep` prints the text when it is not empty.
priv enum LineReply {
  Keep(String, String)
  Halt
}

///|
/// Prompt while a line is being completed. `.. ` means the previous lines are still open.
pub fn prompt_text(pending : String) -> String {
  if pending == "" {
    ">> "
  } else {
    ".. "
  }
}

///|
/// Evaluates one input line against the session buffer.
/// The first string is text to print. The second is the still-open source.
/// `quit` is not an error to print: it raises so the session can end.
pub fn take_line(
  env : @eval.Env,
  pending : String,
  line : String,
) -> (String, String) raise @eval.EvalError {
  if pending == "" && line == "" {
    ("", "")
  } else {
    let source = if pending == "" { line } else { pending + "\n" + line }
    try {
      let cell = @eval.run(env, source)
      match cell {
        @value.Cell::Unset => ("", "")
        _ => (@mold.mold_text(cell), "")
      }
    } catch {
      error =>
        match error {
          @eval.BadSource("missing") => ("", source)
          @eval.Quit => raise @eval.Quit
          _ => (@mold.mold_text(error.to_cell()), "")
        }
    }
  }
}

///|
/// Prints a leftover unclosed fragment when input ends.
/// `quit` raises, the same way a finished line does.
pub fn finish(
  env : @eval.Env,
  pending : String,
) -> String raise @eval.EvalError {
  if pending == "" {
    ""
  } else {
    try {
      let cell = @eval.run(env, pending)
      match cell {
        @value.Cell::Unset => ""
        _ => @mold.mold_text(cell)
      }
    } catch {
      @eval.Quit => raise @eval.Quit
      error => @mold.mold_text(error.to_cell())
    }
  }
}

///|
/// The session's answer for one input line, including `quit`.
fn line_reply(env : @eval.Env, pending : String, line : String) -> LineReply {
  try {
    let stepped = take_line(env, pending, line)
    Keep(stepped.0, stepped.1)
  } catch {
    @eval.Quit => Halt
    error => Keep(@mold.mold_text(error.to_cell()), "")
  }
}

///|
/// The session's answer when input ends with a leftover fragment.
fn finish_reply(env : @eval.Env, pending : String) -> LineReply {
  Keep(finish(env, pending), "") catch {
    @eval.Quit => Halt
    error => Keep(@mold.mold_text(error.to_cell()), "")
  }
}
