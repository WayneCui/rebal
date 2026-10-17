///|
#borrow(host, path)
extern "C" fn c_http_get(
  host : String,
  host_len : Int,
  port : Int,
  path : String,
  path_len : Int,
) -> String = "rebal_http_get"

///|
extern "C" fn c_http_code() -> Int = "rebal_http_code"

///|
extern "C" fn c_http_serve() -> Int = "rebal_http_serve"

///|
/// Serves one `200` response whose body is `ok`. Returns the port.
pub fn http_serve() -> Int {
  c_http_serve()
}

///|
/// `read` performs one HTTP/1.0 GET and returns the body. `query` reports
/// the scheme. Only an IPv4 address is accepted.
fn http_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  let _ = extra
  match action {
    "open" => {
      match port {
        @value.Port(value) => value.set_opened(true)
        _ => ()
      }
      port
    }
    "close" => {
      match port {
        @value.Port(value) => value.set_opened(false)
        _ => ()
      }
      port
    }
    "read" => http_read(env, port)
    "query" => http_query(env, port)
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn http_read(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let (host, number, path) = http_target(env, port)
  let text = c_http_get(host, host.length(), number, path, path.length())
  if c_http_code() == 0 {
    text_series(text)
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn http_query(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let info = @value.Frame::new()
  put_field(env, info, "name", port_ref(env, port))
  put_field(env, info, "size", @value.None)
  put_field(env, info, "type", word_cell(env, "http"))
  @value.Object(info)
}

///|
fn http_target(
  env : Env,
  port : @value.Cell,
) -> (String, Int, String) raise EvalError {
  match port_ref(env, port) {
    @value.Seq(series, index) if series.datatype() == @value.Url =>
      split_http(text_from(series, index))
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn split_http(text : String) -> (String, Int, String) raise EvalError {
  let mark = tcp_mark(text)
  if mark < 0 {
    raise EvalError::Cannot("port")
  }
  let rest = text[mark:text.length()].to_owned()
  let slash = first_slash(rest)
  let authority = if slash < 0 { rest } else { rest[0:slash].to_owned() }
  let path = if slash < 0 { "/" } else { rest[slash:rest.length()].to_owned() }
  let colon = last_colon(authority)
  if colon <= 0 {
    (authority, 80, path)
  } else {
    let host = authority[0:colon].to_owned()
    let number = parse_port(authority[colon + 1:authority.length()].to_owned())
    (host, number, path)
  }
}

///|
fn first_slash(text : String) -> Int {
  let mut index = 0
  while index < text.length() {
    if text[index] == '/' {
      return index
    }
    index = index + 1
  }
  -1
}
