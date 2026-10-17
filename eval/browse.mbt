///|
#borrow(program, target)
extern "C" fn c_browse(
  program : String,
  program_len : Int,
  target : String,
  target_len : Int,
) -> Int = "rebal_browse"

///|
priv struct Browser {
  mut command : String
}

///|
let browser : Browser = { command: "/usr/bin/open", }

///|
pub fn set_browser(command : String) -> Unit {
  browser.command = command
}

///|
/// Hand a url, file, or string to the system opener and return that value.
/// The opener is `/usr/bin/open` unless a test replaces it.
fn perform_browse(value : @value.Cell) -> @value.Cell raise EvalError {
  let target = browse_text(value)
  if target == "" ||
    c_browse(browser.command, browser.command.length(), target, target.length()) !=
    0 {
    raise EvalError::Cannot("browse")
  }
  value
}

///|
fn browse_text(value : @value.Cell) -> String raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Url ||
      series.datatype() == @value.File ||
      series.datatype() == @value.String => text_from(series, index)
    _ => raise EvalError::Cannot("browse")
  }
}
