///|
/// to-* wrappers for the conversions `to` already accepts. `to-image` stays
/// unset until that type exists.
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
  "to-map: func [value] [to map! :value]\n" +
  "to-string: func [value] [to string! :value]\n" +
  "to-binary: func [value] [to binary! :value]\n" +
  "to-word: func [value] [to word! :value]\n" +
  "to-file: func [value] [to file! :value]\n" +
  "to-logic: func [value] [to logic! :value]\n" +
  predicates_script()
}

///|
/// One predicate per datatype, the way boot generates the type checks.
/// `function?` covers the any-function! typeset, like Rebol does.
fn predicates_script() -> String {
  let names = [
    "logic", "integer", "decimal", "percent", "pair", "tuple", "money", "time", "date",
    "char", "word", "set-word", "get-word", "lit-word", "refinement", "string", "file",
    "email", "url", "tag", "issue", "binary", "block", "paren", "path", "set-path",
    "datatype", "op", "object", "error", "bitset", "map", "module", "closure", "port",
    "handle", "event", "vector", "image", "struct", "typeset", "utype",
  ]
  let buf = StringBuilder()
  for name in names {
    buf.write_string(name + "?: func [value] [" + name + "! = type? :value]\n")
  }
  buf.write_string(
    "function?: func [value] [find any-function! type? :value]\n",
  )
  buf.to_string()
}
