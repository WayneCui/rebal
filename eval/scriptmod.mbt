///|
/// Runs a script body under its header. `needs:` entries are imported
/// first; a `type: 'module` header builds a module from the header spec
/// and the body; any other header just leaves the body to evaluate.
/// The header arrives as source text because `load_code` drops it.
fn run_script(
  env : Env,
  loaded : @value.Cell,
  header : String?,
  dir : String,
) -> @value.Cell raise EvalError {
  match header {
    Some(source) =>
      match script_fields(env, source) {
        Some(items) => {
          import_needs(env, items, dir)
          if header_is_module(env, items) {
            perform_module(env, header_spec(items), loaded)
          } else {
            eval(env, loaded)
          }
        }
        None => eval(env, loaded)
      }
    None => eval(env, loaded)
  }
}

///|
/// The header fields as a block again, for `module`'s spec.
fn header_spec(items : Array[@value.Cell]) -> @value.Cell {
  let series = @value.Series::block()
  for item in items {
    series.push_item(item.snapshot()) |> ignore
  }
  @value.Seq(series, 0)
}

///|
/// `type: 'module` in the header fields.
fn header_is_module(env : Env, items : Array[@value.Cell]) -> Bool {
  let mut index = 0
  let mut found = false
  while !found && index + 1 < items.length() {
    match items[index] {
      @value.Sym(@value.SetWord, lexeme) =>
        if env.symbols.canon(lexeme.sym()) == "type" {
          match items[index + 1] {
            @value.Sym(_, name) =>
              found = env.symbols.canon(name.sym()) == "module"
            _ => ()
          }
        }
      _ => ()
    }
    index = index + 1
  }
  found
}

///|
/// Each `needs:` entry is a word, optionally followed by a version scalar.
/// The module lives in `%<name>.reb` beside the importing script, or in the
/// current directory; loading it and importing it brings the exports into
/// the user context.
fn import_needs(
  env : Env,
  items : Array[@value.Cell],
  dir : String,
) -> Unit raise EvalError {
  let mut index = 0
  while index + 1 < items.length() {
    match items[index] {
      @value.Sym(@value.SetWord, lexeme) =>
        if env.symbols.canon(lexeme.sym()) == "needs" {
          match items[index + 1] {
            @value.Seq(series, at) if series.datatype() == @value.Block ||
              series.datatype() == @value.Paren => {
              let mut cursor = if at < 0 { 0 } else { at }
              while cursor < series.length() {
                match series.item(cursor) {
                  Some(@value.Sym(_, name)) => {
                    import_one(env, name.spelling(), dir)
                    cursor = cursor + 1
                    match series.item(cursor) {
                      Some(@value.Tuple(_)) | Some(@value.Decimal(_)) | Some(@value.Integer(_)) =>
                        cursor = cursor + 1
                      _ => ()
                    }
                  }
                  _ => cursor = cursor + 1
                }
              }
            }
            @value.Sym(_, name) => import_one(env, name.spelling(), dir)
            _ => ()
          }
        }
      _ => ()
    }
    index = index + 1
  }
}

///|
fn import_one(env : Env, name : String, dir : String) -> Unit raise EvalError {
  let beside = dir + name + ".reb"
  let found : String? = try {
    let _ = read_binary(beside)
    Some(beside)
  } catch {
    _ => try {
      let _ = read_binary(name + ".reb")
      Some(name + ".reb")
    } catch {
      _ => None
    }
  }
  match found {
    Some(path) => {
      let loaded = do_file(env, path)
      match loaded {
        @value.Module(_) => {
          let _ = perform_import(env, loaded)
          ()
        }
        _ => ()
      }
    }
    None => raise EvalError::Caused("no-module", name)
  }
}
