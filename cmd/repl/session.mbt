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
pub fn take_line(
  env : @eval.Env,
  pending : String,
  line : String,
) -> (String, String) {
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
          _ => (@mold.mold_text(error.to_cell()), "")
        }
    }
  }
}

///|
/// Prints a leftover unclosed fragment when input ends.
pub fn finish(env : @eval.Env, pending : String) -> String {
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
      error => @mold.mold_text(error.to_cell())
    }
  }
}
