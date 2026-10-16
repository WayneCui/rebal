///|
pub(all) suberror EvalError {
  NoValue(String)
  MissingArg(String)
  OpArg(String)
  Cannot(String)
  BadSource(String)
  InvalidPath(String)
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
  }
}
