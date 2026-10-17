///|
/// Asks a question and returns true, false, or none.
/// Without `/with`, `y` and `yes` are true, `n` and `no` are false.
/// `/with` takes a string prefix, or a block of one or two choice groups.
fn perform_confirm(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let _ = env
  let mut custom = false
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "with" {
      custom = true
    } else {
      raise EvalError::Cannot("confirm")
    }
  }
  if custom {
    check_choices(args[1])
  }
  let answer = perform_ask(args[0])
  match answer_text(answer) {
    None => @value.None
    Some(text) =>
      if custom {
        confirm_with(text, args[1])
      } else {
        confirm_yes_no(text)
      }
  }
}

///|
fn check_choices(choices : @value.Cell) -> Unit raise EvalError {
  match choices {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      if series.length() - index > 2 {
        raise EvalError::Caused("invalid-arg", @mold.mold_text(choices))
      }
    _ => ()
  }
}

///|
fn confirm_yes_no(text : String) -> @value.Cell {
  let folded = text.to_lower()
  if folded == "y" || folded == "yes" {
    @value.Logic(true)
  } else if folded == "n" || folded == "no" {
    @value.Logic(false)
  } else {
    @value.None
  }
}

///|
fn confirm_with(
  text : String,
  choices : @value.Cell,
) -> @value.Cell raise EvalError {
  match choices {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      if opens_with(text, text_from(series, index)) {
        @value.Logic(true)
      } else {
        @value.None
      }
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let count = series.length() - index
      if count <= 0 {
        @value.Logic(true)
      } else if count == 1 {
        match series.item(index) {
          Some(item) => confirm_with(text, item)
          None => @value.None
        }
      } else if group_has(series.item(index), text) {
        @value.Logic(true)
      } else if group_has(series.item(index + 1), text) {
        @value.Logic(false)
      } else {
        @value.None
      }
    }
    _ => raise EvalError::Cannot("confirm")
  }
}

///|
fn group_has(item : @value.Cell?, text : String) -> Bool raise EvalError {
  match item {
    Some(@value.Seq(series, index)) if series.datatype() == @value.Block => {
      let folded = text.to_lower()
      let mut cursor = index
      let mut found = false
      while cursor < series.length() && !found {
        match series.item(cursor) {
          Some(@value.Seq(word, at)) if word.datatype() == @value.String =>
            found = text_from(word, at).to_lower() == folded
          _ => ()
        }
        cursor = cursor + 1
      }
      found
    }
    _ => false
  }
}

///|
fn answer_text(cell : @value.Cell) -> String? raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      Some(text_from(series, index))
    _ => None
  }
}

///|
fn opens_with(text : String, prefix : String) -> Bool {
  let left = text.to_lower()
  let right = prefix.to_lower()
  if right.length() == 0 || left.length() < right.length() {
    false
  } else {
    left[0:right.length()].to_owned() == right
  }
}
