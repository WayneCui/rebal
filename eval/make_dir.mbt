///|
/// Creates a directory. An existing directory is returned unchanged.
/// A path that is already a file is an access error. `/deep` creates each
/// missing parent, and removes the ones it created if a later level fails.
fn perform_make_dir(
  env : Env,
  path : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut deep = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "deep" {
      deep = true
    } else {
      raise EvalError::Cannot("make-dir")
    }
  }
  if empty_file(path) {
    return path
  }
  let target = directory_file(path)
  match directory_kind(env, target) {
    "dir" => target
    "file" => raise EvalError::Caused("cannot-open", @mold.mold_text(target))
    _ => if deep { make_deep(env, target) } else { create_one(target) }
  }
}

///|
fn empty_file(path : @value.Cell) -> Bool {
  match path {
    @value.Seq(series, index) if series.datatype() == @value.File =>
      series.length() <= index || (index < 0 && series.length() == 0)
    _ => false
  }
}

///|
fn create_one(target : @value.Cell) -> @value.Cell raise EvalError {
  match target {
    @value.Seq(series, index) => {
      make_dir(text_from(series, index))
      target
    }
    _ => raise EvalError::Cannot("make-dir")
  }
}

///|
fn make_deep(env : Env, target : @value.Cell) -> @value.Cell raise EvalError {
  match target {
    @value.Seq(series, index) => {
      let pending : Array[String] = []
      let mut current = text_from(series, index)
      let mut walking = true
      while walking {
        let kind = directory_kind(env, file_text(current))
        if kind == "dir" {
          walking = false
        } else if kind == "file" {
          raise EvalError::Caused("cannot-open", @mold.mold_text(target))
        } else {
          let slashed = if current.length() > 0 &&
            current[current.length() - 1] == '/' {
            current
          } else {
            current + "/"
          }
          pending.push(slashed)
          let parent = parent_dir(slashed)
          if parent == current || parent == "" {
            walking = false
          } else {
            current = parent
          }
        }
      }
      let created : Array[String] = []
      let mut step = pending.length() - 1
      while step >= 0 {
        let dir = pending[step]
        try {
          make_dir(dir)
          created.push(dir)
        } catch {
          _ => {
            undo_dirs(created)
            raise EvalError::Cannot("access")
          }
        }
        step = step - 1
      }
      target
    }
    _ => raise EvalError::Cannot("make-dir")
  }
}

///|
fn parent_dir(text : String) -> String {
  let mut end = text.length()
  if end > 1 && text[end - 1] == '/' {
    end = end - 1
  }
  let mut slash = -1
  let mut index = 0
  while index < end {
    if text[index] == '/' {
      slash = index
    }
    index = index + 1
  }
  if slash < 0 {
    ""
  } else {
    text[0:slash + 1].to_owned()
  }
}

///|
fn undo_dirs(created : Array[String]) -> Unit {
  let mut index = created.length() - 1
  while index >= 0 {
    remove_made_dir(created[index])
    index = index - 1
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
