///|
/// Builds a module. The body runs in its own frame. Only names listed in
/// `exports:` leave that frame, and only when `import` copies them.
fn perform_module(
  env : Env,
  spec : @value.Cell,
  body : @value.Cell,
) -> @value.Cell raise EvalError {
  let exports = export_names(spec)
  match body {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let frame = @value.Frame::new()
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.SetWord, lexeme)) =>
            frame.ensure(lexeme.sym()) |> ignore
          _ => ()
        }
        cursor = cursor + 1
      }
      @bind.bind(@value.Seq(series, index), frame) |> ignore
      do_series(env, series, index) |> ignore
      @value.Module(@value.ModuleValue::make(frame, exports))
    }
    _ => raise EvalError::Cannot("module")
  }
}

///|
/// Copies each exported word into the user context. Other module words stay put.
fn perform_import(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Module(loaded) => {
      for sym in loaded.exports {
        match loaded.frame.find(sym) {
          Some(slot) =>
            match loaded.frame.get(slot) {
              Some(value) => {
                let user_slot = env.user.ensure(sym)
                store(env.user, user_slot, value)
              }
              None => ()
            }
          None => ()
        }
      }
      cell
    }
    _ => raise EvalError::Cannot("import")
  }
}

///|
fn export_names(spec : @value.Cell) -> Array[Int] raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let names : Array[Int] = []
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.SetWord, lexeme)) => {
            cursor = cursor + 1
            if lexeme.spelling().to_lower() == "exports" {
              read_exports(names, series.item(cursor))
            }
            if cursor < series.length() {
              cursor = cursor + 1
            }
          }
          _ => cursor = cursor + 1
        }
      }
      names
    }
    _ => raise EvalError::Cannot("module")
  }
}

///|
fn read_exports(
  names : Array[Int],
  cell : @value.Cell?,
) -> Unit raise EvalError {
  match cell {
    Some(@value.Seq(series, index)) if series.datatype() == @value.Block => {
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.Word, lexeme)) => names.push(lexeme.sym())
          _ => raise EvalError::Cannot("module")
        }
        cursor = cursor + 1
      }
    }
    _ => raise EvalError::Cannot("module")
  }
}
