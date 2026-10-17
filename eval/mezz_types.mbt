///|
/// to-* wrappers for the conversions `to` already accepts. Words such as
/// to-string and to-image stay unset until those conversions exist.
fn boot_types(env : Env) -> Unit {
  try eval(env, load(env, types_script())) |> ignore catch {
    error => abort(error.id())
  }
}

///|
fn types_script() -> String {
  "to-integer: func [value] [to integer! :value]\n" +
  "to-decimal: func [value] [to decimal! :value]\n" +
  "to-percent: func [value] [to percent! :value]\n" +
  "to-money: func [value] [to money! :value]\n" +
  "to-pair: func [value] [to pair! :value]\n" +
  "to-tuple: func [value] [to tuple! :value]\n" +
  "to-time: func [value] [to time! :value]\n" +
  "to-date: func [value] [to date! :value]\n" +
  "to-bitset: func [value] [to bitset! :value]\n" +
  "to-map: func [value] [to map! :value]\n"
}
