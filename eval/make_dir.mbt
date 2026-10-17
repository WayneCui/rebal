///|
/// Creates a directory. An existing directory is returned unchanged.
/// A path that is already a file is an access error. `/deep` stays out.
fn perform_make_dir(
  env : Env,
  path : @value.Cell,
) -> @value.Cell raise EvalError {
  let target = directory_file(path)
  match directory_kind(env, target) {
    "dir" => target
    "file" => raise EvalError::Caused("cannot-open", @mold.mold_text(target))
    _ => {
      match target {
        @value.Seq(series, index) => make_dir(text_from(series, index))
        _ => raise EvalError::Cannot("make-dir")
      }
      target
    }
  }
}

///|
fn directory_file(path : @value.Cell) -> @value.Cell raise EvalError {
  match path {
    @value.Seq(series, index) if series.datatype() == @value.File => {
      let text = text_from(series, index)
      if text.length() == 0 || text[text.length() - 1] == '/' {
        path
      } else {
        file_text(text + "/")
      }
    }
    _ => raise EvalError::Cannot("make-dir")
  }
}

///|
fn directory_kind(env : Env, path : @value.Cell) -> String {
  try {
    match perform_query(env, path) {
      @value.Object(frame) =>
        match frame_field(env, frame, "type") {
          Some(@value.Sym(_, lexeme)) => lexeme.spelling()
          _ => ""
        }
      _ => ""
    }
  } catch {
    _ => ""
  }
}
