///|
extern "C" fn c_sleep(seconds : Double) -> Int = "rebal_sleep"

///|
/// Sleep for an integer, decimal, or time. A port, or a block of ports, runs
/// the async TCP wait loop: accept/read/wrote events call each port's
/// `awake`. A number inside that block is the timeout in seconds. Returning
/// `true` from `awake` ends the wait with `none`.
fn perform_wait(
  env : Env,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  match value {
    @value.None => @value.None
    @value.Port(_) => {
      watch_port(value)
      wait_ports(env, None)
    }
    @value.Seq(series, _) if series.datatype() == @value.Block => {
      // Oldes evaluates the block first, so `wait [server 1]` sees the port.
      let reduced = reduce_block(env, value)
      match reduced {
        @value.Seq(items, start) => {
          let mut delay : Double? = None
          let mut cursor = start
          while cursor < items.length() {
            match items.item(cursor) {
              Some(item) =>
                match item {
                  @value.Port(_) => watch_port(item)
                  _ => delay = note_wait(item, delay)
                }
              None => ()
            }
            cursor = cursor + 1
          }
          wait_ports(env, delay)
        }
        @value.Port(_) => {
          watch_port(reduced)
          wait_ports(env, None)
        }
        _ => {
          sleep_for(duration(reduced))
          @value.None
        }
      }
    }
    _ => {
      sleep_for(duration(value))
      @value.None
    }
  }
}

///|
fn note_wait(item : @value.Cell, delay : Double?) -> Double? raise EvalError {
  match item {
    @value.None | @value.Port(_) => delay
    _ =>
      match delay {
        Some(_) => raise EvalError::Cannot("wait")
        None => Some(duration(item))
      }
  }
}

///|
fn duration(value : @value.Cell) -> Double raise EvalError {
  match value {
    @value.Integer(n) => n.to_double()
    @value.Decimal(n) => n
    @value.Time(n) => n
    _ => raise EvalError::Cannot("wait")
  }
}

///|
fn sleep_for(seconds : Double) -> Unit raise EvalError {
  if c_sleep(seconds) != 0 {
    raise EvalError::Cannot("wait")
  }
}

///|
fn wait_ports(
  env : Env,
  delay : Double?,
) -> @value.Cell raise EvalError {
  let deadline = match delay {
    Some(seconds) => {
      if seconds < 0.0 {
        raise EvalError::Cannot("wait")
      }
      Some(now_ms() + (seconds * 1000.0).to_int64())
    }
    None => None
  }
  let mut running = true
  while running {
    if drain_pending_wrote(env) {
      return @value.None
    }
    let left_ms = match deadline {
      Some(end) => {
        let left = end - now_ms()
        if left <= 0L {
          running = false
          0
        } else if left > 2147483647L {
          2147483647
        } else {
          left.to_int()
        }
      }
      None => -1
    }
    if !running {
      break
    }
    c_poll_clear()
    let mut any = false
    for cell in watched_ports {
      match cell {
        @value.Port(value) =>
          if value.is_open() && value.handle() >= 0 {
            match value.kind() {
              @value.PortKind::TcpListen => {
                c_poll_add(value.handle(), 1) |> ignore
                any = true
              }
              @value.PortKind::TcpAsync =>
                if value.want_read() {
                  c_poll_add(value.handle(), 2) |> ignore
                  any = true
                }
              @value.PortKind::TcpSync => ()
            }
          }
        _ => ()
      }
    }
    if !any {
      match deadline {
        Some(_) => {
          sleep_for(left_ms.to_double() / 1000.0)
          running = false
        }
        None => sleep_for(0.05)
      }
    } else {
      let n = c_poll_wait(left_ms)
      let mut i = 0
      while i < n {
        let fd = c_poll_ready_fd_at(i)
        let tag = c_poll_ready_tag_at(i)
        if tag == 1 {
          if handle_accept(env, fd) {
            return @value.None
          }
        } else if tag == 2 {
          if handle_readable(env, fd) {
            return @value.None
          }
        }
        i = i + 1
      }
      match deadline {
        Some(end) =>
          if now_ms() >= end {
            running = false
          }
        None => ()
      }
    }
  }
  @value.None
}

///|
extern "C" fn c_now_ms() -> Int64 = "rebal_now_ms"

///|
fn now_ms() -> Int64 {
  c_now_ms()
}

///|
fn drain_pending_wrote(env : Env) -> Bool raise EvalError {
  for cell in watched_ports {
    match cell {
      @value.Port(value) =>
        if value.pending_wrote() {
          value.set_pending_wrote(false)
          if fire_awake(env, cell, "wrote") {
            return true
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn handle_accept(env : Env, listen_fd : Int) -> Bool raise EvalError {
  match find_watched(listen_fd) {
    Some(listen) =>
      match listen {
        @value.Port(value) => {
          let conn = c_tcp_accept(listen_fd)
          if conn < 0 {
            false
          } else {
            let child = make_async_tcp_port(env, conn)
            value.push_accept(child)
            fire_awake(env, listen, "accept")
          }
        }
        _ => false
      }
    None => false
  }
}

///|
fn handle_readable(env : Env, fd : Int) -> Bool raise EvalError {
  match find_watched(fd) {
    Some(cell) =>
      match cell {
        @value.Port(value) => {
          value.set_want_read(false)
          let packed = c_tcp_recv_bytes(fd)
          let code = c_tcp_code()
          if code == 2 {
            fire_awake(env, cell, "close")
          } else if code == 0 {
            value.set_data(binary_cell(codes_of(packed)))
            fire_awake(env, cell, "read")
          } else if code == 3 {
            value.set_want_read(true)
            false
          } else {
            fire_awake(env, cell, "close")
          }
        }
        _ => false
      }
    None => false
  }
}

///|
fn find_watched(fd : Int) -> @value.Cell? {
  for cell in watched_ports {
    match cell {
      @value.Port(value) =>
        if value.handle() == fd {
          return Some(cell)
        }
      _ => ()
    }
  }
  None
}

///|
fn fire_awake(
  env : Env,
  port : @value.Cell,
  kind : String,
) -> Bool raise EvalError {
  match port {
    @value.Port(value) => {
      let awake = value.awake()
      match awake {
        @value.Function(func) => {
          let event = make_port_event(env, kind, port)
          let result = call_user(env, func, [event], [])
          is_awake_stop(result)
        }
        _ => false
      }
    }
    _ => false
  }
}

///|
fn is_awake_stop(cell : @value.Cell) -> Bool {
  match cell {
    @value.Logic(true) => true
    _ => false
  }
}

///|
fn make_port_event(
  _env : Env,
  kind : String,
  port : @value.Cell,
) -> @value.Cell {
  let event = @value.EventValue::blank()
  event.set_kind(kind)
  event.set_port(port)
  @value.Event(event)
}
