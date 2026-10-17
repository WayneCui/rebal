///|
pub(all) suberror EvalError {
  NoValue(String)
  MissingArg(String)
  OpArg(String)
  Cannot(String)
  BadSource(String)
  InvalidPath(String)
  /// A function exit. Callers re-raise this instead of boxing it.
  Returned(@value.Cell)
  /// `return` reached the top of `run` with no function to leave.
  NoReturn
  /// Leaves the innermost loop. Loops catch it; everyone else re-raises it.
  Broken
  /// `break` reached `run` with no loop to leave.
  NoBreak
}

///|
/// Boxes this failure as an `error!` value.
pub fn EvalError::to_cell(self : EvalError) -> @value.Cell {
  let (id, arg) = match self {
    NoValue(text) => ("no-value", text)
    MissingArg(text) => ("missing-arg", text)
    OpArg(text) => ("no-op-arg", text)
    Cannot(text) => ("cannot", text)
    BadSource(text) => ("bad-source", text)
    InvalidPath(text) => ("invalid-path", text)
    Returned(_) => ("return", "return")
    NoReturn => ("return", "return")
    Broken => ("break", "break")
    NoBreak => ("break", "break")
  }
  @value.Error(@value.ErrorValue::make(id, arg, ""))
}

///|
pub fn EvalError::id(self : EvalError) -> String {
  match self {
    NoValue(_) => "no-value"
    MissingArg(_) => "missing-arg"
    OpArg(_) => "no-op-arg"
    Cannot(_) => "cannot"
    BadSource(_) => "bad-source"
    InvalidPath(_) => "invalid-path"
    Returned(_) => "return"
    NoReturn => "return"
    Broken => "break"
    NoBreak => "break"
  }
}
