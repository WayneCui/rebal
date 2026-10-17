///|
extern "C" fn c_current_dir() -> String = "rebal_current_dir"

///|
extern "C" fn c_cwd_code() -> Int = "rebal_cwd_code"

///|
#borrow(path)
extern "C" fn c_change_dir(path : String, path_len : Int) -> Int = "rebal_change_dir"

///|
/// The current directory as a file, with a trailing slash.
fn perform_what_dir() -> @value.Cell raise EvalError {
  let text = c_current_dir()
  if c_cwd_code() == 0 {
    file_text(text)
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
/// Moves to a directory and returns that directory as an absolute file.
fn perform_change_dir(path : @value.Cell) -> @value.Cell raise EvalError {
  match path {
    @value.Seq(series, index) if series.datatype() == @value.File => {
      let text = text_from(series, index)
      if c_change_dir(text, text.length()) == 0 {
        perform_what_dir()
      } else {
        raise EvalError::Cannot("access")
      }
    }
    _ => raise EvalError::Cannot("change-dir")
  }
}

///|
fn file_text(text : String) -> @value.Cell {
  let series = @value.Series::text_of(@value.File)
  for char in text {
    series.push_code(char.to_int()) |> ignore
  }
  @value.Seq(series, 0)
}
