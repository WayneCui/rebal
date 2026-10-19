///|
/// Startup options. `path` is the directory where evaluation started.
/// `args` is an empty block until a host passes script arguments.
/// `script` stays `none` until a host names a startup script.
/// Changing directory later does not move `path`.
fn boot_system(env : Env) -> Unit {
  let options = @value.Frame::new()
  set_option(env, options, "path", startup_dir())
  set_option(env, options, "args", @value.Seq(@value.Series::block(), 0))
  set_option(env, options, "script", @value.None)
  let script = @value.Frame::new()
  set_option(env, script, "args", @value.None)
  let system = @value.Frame::new()
  set_option(env, system, "options", @value.Object(options))
  set_option(env, system, "script", @value.Object(script))
  install(env, "system", @value.Object(system))
}

///|
fn set_option(
  env : Env,
  frame : @value.Frame,
  spelling : String,
  cell : @value.Cell,
) -> Unit {
  let slot = frame.ensure(env.symbols.intern(spelling))
  frame.set(slot, cell) |> ignore
}

///|
fn startup_dir() -> @value.Cell {
  perform_what_dir() catch {
    _ => @value.None
  }
}
