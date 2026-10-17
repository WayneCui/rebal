///|
/// The system port holds no events yet. `read` is the empty wake list.
/// `write` has nothing to deliver.
fn system_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  let _ = extra
  match action {
    "open" => {
      set_port_open(port, true)
      port
    }
    "close" => {
      set_port_open(port, false)
      port
    }
    "read" => @value.Seq(@value.Series::block(), 0)
    "query" => {
      let info = @value.Frame::new()
      put_field(env, info, "type", word_cell(env, "system"))
      @value.Object(info)
    }
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn set_port_open(port : @value.Cell, flag : Bool) -> Unit {
  match port {
    @value.Port(value) => value.set_opened(flag)
    _ => ()
  }
}
