///|
/// Resolves `.`, `..`, and repeated slashes. A relative file is based on
/// the current directory unless `/only` is set. `/dir` keeps a trailing slash.
fn perform_clean_path(
  env : Env,
  path : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut only = false
  let mut as_dir = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "only" {
      only = true
    } else if name == "dir" {
      as_dir = true
    } else {
      raise EvalError::Cannot("clean-path")
    }
  }
  match path {
    @value.Seq(series, index) if @value.text_series(series.datatype()) => {
      let text = text_from(series, index)
      let absolute = if series.datatype() == @value.File && !only {
        rooted_file(text)
      } else {
        text
      }
      series_text(series.datatype(), force_dir(collapse_text(absolute), as_dir))
    }
    _ => raise EvalError::Cannot("clean-path")
  }
}

///|
fn force_dir(text : String, as_dir : Bool) -> String {
  if as_dir && (text.length() == 0 || text[text.length() - 1] != '/') {
    text + "/"
  } else {
    text
  }
}

///|
fn rooted_file(text : String) -> String raise EvalError {
  if text.length() > 0 && text[0] == '/' {
    text
  } else {
    match perform_what_dir() {
      @value.Seq(series, index) => text_from(series, index) + text
      _ => raise EvalError::Cannot("clean-path")
    }
  }
}

///|
fn collapse_text(text : String) -> String {
  match scheme_end(text) {
    Some(at) => text[0:at].to_owned() + collapse_body(text[at:].to_owned())
    None => collapse_body(text)
  }
}

///|
fn scheme_end(text : String) -> Int? {
  let mut index = 0
  let mut found : Int? = None
  while index + 2 < text.length() && found is None {
    if text[index] == ':' && text[index + 1] == '/' && text[index + 2] == '/' {
      found = Some(index + 3)
    }
    index = index + 1
  }
  found
}

///|
fn keep_part(parts : Array[String], name : String, absolute : Bool) -> Unit {
  if name == ".." {
    if parts.length() > 0 && parts[parts.length() - 1] != ".." {
      parts.remove(parts.length() - 1) |> ignore
    } else if !absolute {
      parts.push("..")
    }
  } else if name != "" && name != "." {
    parts.push(name)
  }
}

///|
fn collapse_body(text : String) -> String {
  let absolute = text.length() > 0 && text[0] == '/'
  let trailing = text.length() > 0 && text[text.length() - 1] == '/'
  let parts : Array[String] = []
  let mut buf = StringBuilder()
  for char in text {
    if char == '/' {
      keep_part(parts, buf.to_string(), absolute)
      buf = StringBuilder()
    } else {
      buf.write_char(char)
    }
  }
  keep_part(parts, buf.to_string(), absolute)
  let out = StringBuilder()
  if absolute {
    out.write_char('/')
  }
  let mut part = 0
  while part < parts.length() {
    if part > 0 {
      out.write_char('/')
    }
    out.write_string(parts[part])
    part = part + 1
  }
  if trailing && !(absolute && parts.length() == 0) {
    out.write_char('/')
  }
  out.to_string()
}

///|
fn series_text(datatype : @value.Datatype, text : String) -> @value.Cell {
  let series = @value.Series::text_of(datatype)
  for char in text {
    series.push_code(char.to_int()) |> ignore
  }
  @value.Seq(series, 0)
}
