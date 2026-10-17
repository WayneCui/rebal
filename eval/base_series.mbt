///|
/// repend, reform, and join from base-series. ellipsize stays out: it binds
/// against system/catalog/bitsets, which this interpreter does not build.
fn boot_series(env : Env) -> Unit {
  try eval(env, load(env, series_script())) |> ignore catch {
    error => abort(error.id())
  }
}

///|
fn series_script() -> String {
  "repend: func [series value] [append series reduce :value]\n" +
  "reform: func [value] [form reduce :value]\n" +
  "join: func [value rest] [\n" +
  "append either series? :value [copy value] [form :value] reduce :rest\n" +
  "]\n"
}
