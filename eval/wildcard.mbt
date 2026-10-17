///|
/// Lists the files in a directory whose whole name matches `*` and `?`.
/// `*` is any run of characters, `?` is one character. Matching ignores case.
fn perform_wildcard(
  env : Env,
  path : @value.Cell,
  pattern : @value.Cell,
) -> @value.Cell raise EvalError {
  match (path, pattern) {
    (@value.Seq(dir, dir_index), @value.Seq(mask, mask_index)) if dir.datatype() ==
      @value.File &&
      @value.text_series(mask.datatype()) => {
      let cleaned = perform_clean_path(env, @value.Seq(dir, dir_index), [
        env.symbols.intern("dir"),
      ])
      let folder = match cleaned {
        @value.Seq(series, index) => text_from(series, index)
        _ => raise EvalError::Cannot("wildcard")
      }
      let names = split_lines(list_dir(folder))
      sort_names(names)
      let wanted = text_from(mask, mask_index)
      let block = @value.Series::block()
      for name in names {
        if glob_match(name, wanted) {
          block.push_item(file_cell(folder + name)) |> ignore
        }
      }
      @value.Seq(block, 0)
    }
    _ => raise EvalError::Cannot("wildcard")
  }
}

///|
fn glob_match(name : String, pattern : String) -> Bool {
  glob_at(name.to_lower(), pattern.to_lower(), 0, 0)
}

///|
fn glob_at(
  name : String,
  pattern : String,
  name_at : Int,
  pattern_at : Int,
) -> Bool {
  if pattern_at == pattern.length() {
    name_at == name.length()
  } else if pattern[pattern_at] == '*' {
    let mut next = pattern_at + 1
    while next < pattern.length() && pattern[next] == '*' {
      next = next + 1
    }
    if next == pattern.length() {
      true
    } else {
      let mut at = name_at
      let mut found = false
      while at <= name.length() && !found {
        if glob_at(name, pattern, at, next) {
          found = true
        }
        at = at + 1
      }
      found
    }
  } else if name_at == name.length() {
    false
  } else if pattern[pattern_at] == '?' || pattern[pattern_at] == name[name_at] {
    glob_at(name, pattern, name_at + 1, pattern_at + 1)
  } else {
    false
  }
}
