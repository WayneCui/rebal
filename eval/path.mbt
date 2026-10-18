///|
fn is_set_path(series : @value.Series) -> Bool {
  if series.datatype() == @value.SetPath {
    true
  } else if series.datatype() == @value.Path && series.length() > 1 {
    match series.item(series.length() - 1) {
      Some(@value.Sym(@value.SetWord, _)) => true
      _ => false
    }
  } else {
    false
  }
}

///|
fn path_get(
  env : Env,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  walk_path(env, series, index, series.length())
}

///|
fn path_set(
  env : Env,
  series : @value.Series,
  index : Int,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let last = series.length() - 1
  if last <= index {
    raise EvalError::InvalidPath("path")
  }
  let container = walk_path(env, series, index, last)
  match series.item(last) {
    Some(selector) => {
      write_selector(container, selector, value)
      value
    }
    None => raise EvalError::InvalidPath("path")
  }
}

///|
fn walk_path(
  env : Env,
  series : @value.Series,
  index : Int,
  until : Int,
) -> @value.Cell raise EvalError {
  if index >= until {
    raise EvalError::InvalidPath("path")
  }
  let mut current = path_head(env, series, index)
  let mut cursor = index + 1
  while cursor < until {
    match series.item(cursor) {
      Some(selector) => current = path_step(env, current, selector)
      None => raise EvalError::InvalidPath("path")
    }
    cursor = cursor + 1
  }
  current
}

///|
fn path_head(
  env : Env,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  match series.item(index) {
    Some(@value.Sym(@value.Word, lexeme)) =>
      fetch(env, series, index, @value.Word, lexeme)
    Some(@value.Sym(@value.GetWord, lexeme)) =>
      fetch(env, series, index, @value.GetWord, lexeme)
    Some(@value.Seq(nested, nested_index)) if nested.datatype() == @value.Paren =>
      do_series(env, nested, nested_index)
    Some(cell) => cell
    None => raise EvalError::InvalidPath("path")
  }
}

///|
fn path_step(
  env : Env,
  current : @value.Cell,
  selector : @value.Cell,
) -> @value.Cell raise EvalError {
  match current {
    @value.Object(frame) =>
      match selector {
        @value.Sym(_, lexeme) => object_field(frame, lexeme)
        _ => raise EvalError::InvalidPath("object")
      }
    @value.Error(error) => error_field(env, error, selector)
    @value.Seq(series, index) => step_series(series, index, selector)
    @value.Pair(x, y) => pair_field(x, y, selector)
    @value.Vector(vector) =>
      match selector {
        @value.Integer(index) =>
          match vector.at(index.to_int()) {
            Some(cell) => cell
            None => @value.Cell::None
          }
        _ => raise EvalError::InvalidPath("vector")
      }
    @value.Image(image) => image_field(env, image, selector)
    @value.Struct(fields) => struct_field_at(env, fields, selector)
    @value.Handle(handle) => handle_field(env, handle, selector)
    @value.Event(event) => event_field(env, event, selector)
    @value.Map(map) =>
      match map.get(selector) {
        Some(found) => found
        None => @value.None
      }
    @value.Port(port) => port_field(port, selector)
    _ => raise EvalError::InvalidPath("path")
  }
}

///|
/// `error!` exposes `id` as a word and `arg1` as the stored text.
fn error_field(
  env : Env,
  error : @value.ErrorValue,
  selector : @value.Cell,
) -> @value.Cell raise EvalError {
  match selector {
    @value.Sym(_, lexeme) => {
      let name = env.symbols.canon(lexeme.sym())
      if name == "id" {
        codec_word(env, error.id)
      } else if name == "arg1" {
        if error.arg1 == "" {
          @value.Cell::None
        } else {
          text_series(error.arg1)
        }
      } else {
        raise EvalError::InvalidPath(lexeme.spelling())
      }
    }
    _ => raise EvalError::InvalidPath("error")
  }
}

///|
fn pair_field(
  x : Int64,
  y : Int64,
  selector : @value.Cell,
) -> @value.Cell raise EvalError {
  match selector {
    @value.Sym(_, lexeme) =>
      if lexeme.spelling() == "x" {
        @value.Integer(x)
      } else if lexeme.spelling() == "y" {
        @value.Integer(y)
      } else {
        raise EvalError::InvalidPath(lexeme.spelling())
      }
    @value.Integer(1L) => @value.Integer(x)
    @value.Integer(2L) => @value.Integer(y)
    _ => raise EvalError::InvalidPath("pair")
  }
}

///|
fn object_field(
  frame : @value.Frame,
  lexeme : @value.Lexeme,
) -> @value.Cell raise EvalError {
  match frame.find(lexeme.sym()) {
    Some(slot) => defined(frame, slot, lexeme.spelling())
    None => raise EvalError::InvalidPath(lexeme.spelling())
  }
}

///|
fn step_series(
  series : @value.Series,
  index : Int,
  selector : @value.Cell,
) -> @value.Cell raise EvalError {
  match selector {
    @value.Integer(n) =>
      if n >= -2147483648L && n <= 2147483647L {
        @series.pick(@value.Seq(series, index), n.to_int())
      } else {
        raise EvalError::InvalidPath("index")
      }
    @value.Sym(_, lexeme) => select_word(series, index, lexeme.sym())
    _ => raise EvalError::InvalidPath("series")
  }
}

///|
/// A word in a block selects the following value. A miss is `none`.
fn select_word(series : @value.Series, index : Int, sym : Int) -> @value.Cell {
  let mut cursor = index
  let mut result = @value.Cell::None
  let mut reading = true
  while reading && cursor + 1 < series.length() {
    match series.item(cursor) {
      Some(@value.Sym(_, lexeme)) =>
        if lexeme.sym() == sym {
          match series.item(cursor + 1) {
            Some(cell) => result = cell
            None => ()
          }
          reading = false
        }
      _ => ()
    }
    cursor = cursor + 1
  }
  result
}

///|
fn write_selector(
  container : @value.Cell,
  selector : @value.Cell,
  value : @value.Cell,
) -> Unit raise EvalError {
  match container {
    @value.Object(frame) =>
      match selector {
        @value.Sym(_, lexeme) =>
          match frame.find(lexeme.sym()) {
            Some(slot) => store(frame, slot, value)
            None => raise EvalError::InvalidPath(lexeme.spelling())
          }
        _ => raise EvalError::InvalidPath("object")
      }
    @value.Seq(series, index) => write_series(series, index, selector, value)
    @value.Map(map) => map.put(selector, value)
    _ => raise EvalError::InvalidPath("path")
  }
}

///|
fn write_series(
  series : @value.Series,
  index : Int,
  selector : @value.Cell,
  value : @value.Cell,
) -> Unit raise EvalError {
  match selector {
    @value.Integer(n) =>
      if n >= -2147483648L &&
        n <= 2147483647L &&
        @series.poke(@value.Seq(series, index), n.to_int(), value) is Some(_) {
        ()
      } else {
        raise EvalError::InvalidPath("index")
      }
    @value.Sym(_, lexeme) => {
      let pos = word_slot(series, index, lexeme.sym())
      match pos {
        Some(at) =>
          if series.set_item(at, value) {
            ()
          } else {
            raise EvalError::InvalidPath(lexeme.spelling())
          }
        None => raise EvalError::InvalidPath(lexeme.spelling())
      }
    }
    _ => raise EvalError::InvalidPath("series")
  }
}

///|
fn word_slot(series : @value.Series, index : Int, sym : Int) -> Int? {
  let mut cursor = index
  let mut found : Int? = None
  while found is None && cursor + 1 < series.length() {
    match series.item(cursor) {
      Some(@value.Sym(_, lexeme)) =>
        if lexeme.sym() == sym {
          found = Some(cursor + 1)
        }
      _ => ()
    }
    cursor = cursor + 1
  }
  found
}
