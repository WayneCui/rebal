///|
/// `has`, `map`, and `context` from mezz-func. `task` and `enum` need types
/// this interpreter does not have.
fn boot_funcs(env : Env) -> Unit {
  try eval(env, load(env, funcs_script())) |> ignore catch {
    error => abort(error.id())
  }
}

///|
fn funcs_script() -> String {
  "has: func [vars [block!] body [block!]] [\n" +
  "func head insert copy vars /local body\n" +
  "]\n" +
  "map: func [val] [make map! :val]\n" +
  "context: func [blk [block!]] [make object! blk]\n"
}
