///|
#borrow(host)
extern "C" fn c_tls_connect(
  host : String,
  host_len : Int,
  port : Int,
  verify : Int,
) -> Int = "rebal_tls_connect"

///|
#borrow(text)
extern "C" fn c_tls_send(handle : Int, text : String, text_len : Int) -> Int = "rebal_tls_send"

///|
extern "C" fn c_tls_recv(handle : Int) -> String = "rebal_tls_recv"

///|
extern "C" fn c_tls_code() -> Int = "rebal_tls_code"

///|
extern "C" fn c_tls_close(handle : Int) -> Int = "rebal_tls_close"

///|
extern "C" fn c_tls_serve() -> Int = "rebal_tls_serve"

///|
priv struct TlsHost {
  mut verify : Bool
}

///|
let tls_host : TlsHost = { verify: true, }

///|
/// When false, a later `open` accepts a peer certificate that is not trusted.
/// The default checks the certificate.
pub fn set_tls_verify(flag : Bool) -> Unit {
  tls_host.verify = flag
}

///|
/// Listens on 127.0.0.1 with a fresh certificate and echoes one line.
/// Returns the port.
pub fn tls_serve() -> Int {
  c_tls_serve()
}

///|
/// `open` handshakes with `tls://host:port`. `write` and `read` move
/// plaintext. Only an IPv4 address is accepted. A peer certificate is
/// checked unless `set_tls_verify` turned that off.
fn tls_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  match action {
    "open" => tls_open(env, port)
    "close" => tls_close(port)
    "read" => tls_read(port)
    "write" =>
      match extra {
        Some(value) => tls_write(port, value)
        None => raise EvalError::Cannot("write")
      }
    "query" => tls_query(env, port)
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn tls_open(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let (host, number) = tls_address(env, port)
  let verify = if tls_host.verify { 1 } else { 0 }
  let handle = c_tls_connect(host, host.length(), number, verify)
  if handle < 0 {
    raise EvalError::Cannot("access")
  }
  match port {
    @value.Port(value) => {
      value.set_handle(handle)
      value.set_opened(true)
    }
    _ => ()
  }
  port
}

///|
fn tls_close(port : @value.Cell) -> @value.Cell {
  match port {
    @value.Port(value) => {
      if value.handle() >= 0 {
        c_tls_close(value.handle()) |> ignore
        value.set_handle(-1)
      }
      value.set_opened(false)
    }
    _ => ()
  }
  port
}

///|
fn tls_read(port : @value.Cell) -> @value.Cell raise EvalError {
  let text = c_tls_recv(tls_handle(port))
  if c_tls_code() == 0 {
    text_series(text)
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn tls_write(
  port : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index)
    _ => @mold.mold_text(value)
  }
  if c_tls_send(tls_handle(port), text, text.length()) == 0 {
    port
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn tls_query(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let info = @value.Frame::new()
  put_field(env, info, "name", port_ref(env, port))
  put_field(env, info, "size", @value.None)
  put_field(env, info, "type", word_cell(env, "tls"))
  @value.Object(info)
}

///|
fn tls_handle(port : @value.Cell) -> Int raise EvalError {
  match port {
    @value.Port(value) => value.handle()
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn tls_address(env : Env, port : @value.Cell) -> (String, Int) raise EvalError {
  match port_ref(env, port) {
    @value.Seq(series, index) if series.datatype() == @value.Url =>
      split_tcp(text_from(series, index))
    _ => raise EvalError::Cannot("port")
  }
}
