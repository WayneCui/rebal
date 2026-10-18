///|
/// `make event! [type: 'connect]`. A key with no type becomes `key`.
/// Offset components must fit in a signed 16-bit integer.
fn make_event(
  base : @value.EventValue?,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  let event = match base {
    Some(value) => value.copy()
    None => @value.EventValue::blank()
  }
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      event_fields(event, series, index)
      @value.Event(event)
    }
    _ => raise EvalError::Caused("expect-val", "event!")
  }
}

///|
fn event_fields(
  event : @value.EventValue,
  series : @value.Series,
  index : Int,
) -> Unit raise EvalError {
  let items : Array[@value.Cell] = []
  for cursor in index..<series.length() {
    match series.item(cursor) {
      Some(item) => items.push(item)
      None => ()
    }
  }
  let mut cursor = 0
  while cursor < items.length() {
    let name = match items[cursor] {
      @value.Sym(_, lexeme) => lexeme.spelling().to_lower()
      _ => raise EvalError::Caused("bad-field-set", "")
    }
    cursor = cursor + 1
    let value = if cursor < items.length() {
      let cell = items[cursor]
      cursor = cursor + 1
      cell
    } else {
      @value.Cell::None
    }
    event_set(event, name, value)
  }
}

///|
fn event_set(
  event : @value.EventValue,
  name : String,
  value : @value.Cell,
) -> Unit raise EvalError {
  if name == "type" {
    match event_word(value) {
      Some(kind) =>
        if event_type(kind) {
          event.set_kind(kind)
        } else {
          raise EvalError::Caused("invalid-arg", "")
        }
      None => raise EvalError::Caused("bad-field-set", "")
    }
  } else if name == "offset" {
    match value {
      @value.Pair(x, y) =>
        if offset_ok(x) && offset_ok(y) {
          event.set_offset(x.to_int(), y.to_int())
        } else {
          raise EvalError::Caused("out-of-range", "")
        }
      _ => raise EvalError::Caused("bad-field-set", "")
    }
  } else if name == "key" {
    match value {
      @value.Char(code) => {
        if event.kind() == "" {
          event.set_kind("key")
        }
        event.set_code(code)
      }
      _ => raise EvalError::Caused("bad-field-set", "")
    }
  } else if name == "code" {
    match value {
      @value.Integer(code) =>
        if code >= -2147483648L && code <= 2147483647L {
          event.set_code(code.to_int())
        } else {
          raise EvalError::Caused("out-of-range", "")
        }
      _ => raise EvalError::Caused("bad-field-set", "")
    }
  } else if name == "port" {
    match value {
      @value.Port(_) | @value.Object(_) | @value.Cell::None =>
        event.set_port(value)
      _ => raise EvalError::Caused("bad-field-set", "")
    }
  } else {
    raise EvalError::Caused("bad-field-set", "")
  }
}

///|
fn event_word(cell : @value.Cell) -> String? {
  match cell {
    @value.Sym(kind, lexeme) if kind == @value.Word || kind == @value.LitWord =>
      Some(lexeme.spelling().to_lower())
    _ => None
  }
}

///|
fn offset_ok(value : Int64) -> Bool {
  value >= -32767L && value <= 32767L
}

///|
fn event_field(
  env : Env,
  event : @value.EventValue,
  selector : @value.Cell,
) -> @value.Cell raise EvalError {
  match selector {
    @value.Sym(_, lexeme) => {
      let name = env.symbols.canon(lexeme.sym())
      if name == "type" {
        event_kind_word(env, event)
      } else if name == "offset" {
        match event.offset() {
          Some((x, y)) => @value.Pair(x.to_int64(), y.to_int64())
          None => @value.Cell::None
        }
      } else if name == "key" {
        if event.shows_key() {
          match event.code() {
            Some(code) => @value.Char(code & 255)
            None => @value.Cell::None
          }
        } else {
          @value.Cell::None
        }
      } else if name == "code" {
        match event.code() {
          Some(code) => @value.Integer(code.to_int64())
          None => @value.Cell::None
        }
      } else if name == "port" {
        event.port()
      } else {
        raise EvalError::InvalidPath(lexeme.spelling())
      }
    }
    _ => raise EvalError::InvalidPath("event")
  }
}

///|
fn event_kind_word(env : Env, event : @value.EventValue) -> @value.Cell {
  let kind = event.kind()
  if kind == "" {
    @value.Cell::None
  } else {
    @value.Sym(@value.Word, @value.Lexeme::make(env.symbols.intern(kind), kind))
  }
}

///|
fn event_type(name : String) -> Bool {
  match name {
    "ignore"
    | "interrupt"
    | "device"
    | "callback"
    | "custom"
    | "error"
    | "init"
    | "open"
    | "close"
    | "connect"
    | "accept"
    | "read"
    | "write"
    | "wrote"
    | "lookup"
    | "ready"
    | "done"
    | "time"
    | "show"
    | "hide"
    | "offset"
    | "resize"
    | "active"
    | "inactive"
    | "minimize"
    | "maximize"
    | "restore"
    | "move"
    | "down"
    | "up"
    | "alt-down"
    | "alt-up"
    | "aux-down"
    | "aux-up"
    | "key"
    | "key-up"
    | "scroll-line"
    | "scroll-page"
    | "drop-file"
    | "click"
    | "change"
    | "focus"
    | "unfocus"
    | "scroll"
    | "control"
    | "control-up"
    | "char" => true
    _ => false
  }
}
