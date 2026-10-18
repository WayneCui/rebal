///|
/// `rc4/key` returns a stream handle. `rc4/stream` XORs a binary in place.
fn perform_rc4(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut mode = ""
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "key" || name == "stream" {
      if mode != "" {
        raise EvalError::Cannot("rc4")
      }
      mode = name
    } else {
      raise EvalError::Cannot("rc4")
    }
  }
  if mode == "key" {
    match @value.Rc4Key::setup(payload_bytes(args[0], "rc4")) {
      Some(key) => @value.Handle(@value.HandleValue::Rc4(key))
      None => @value.None
    }
  } else if mode == "stream" {
    rc4_stream(args[0], args[1])
  } else {
    raise EvalError::Cannot("rc4")
  }
}

///|
fn rc4_extra(env : Env, active : Array[Int]) -> Int {
  let mut extra = 0
  if named(env, active, "key") {
    extra = extra + 1
  }
  if named(env, active, "stream") {
    extra = extra + 2
  }
  extra
}

///|
fn rc4_stream(
  handle : @value.Cell,
  data : @value.Cell,
) -> @value.Cell raise EvalError {
  match handle {
    @value.Handle(@value.Rc4(key)) =>
      if key.released() {
        raise EvalError::Cannot("rc4")
      } else {
        match data {
          @value.Seq(series, index) if series.datatype() == @value.Binary => {
            let coded = key.xor(bytes_from(series, index))
            let mut cursor = 0
            while cursor < coded.length() {
              series.set_byte(index + cursor, coded[cursor].to_byte()) |> ignore
              cursor = cursor + 1
            }
            data
          }
          _ => raise EvalError::Cannot("rc4")
        }
      }
    _ => raise EvalError::Cannot("rc4")
  }
}
