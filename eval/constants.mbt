///|
/// The boot constants from base-constants. `REBOL`, `sys`, and `lib` stay
/// as they were installed.
fn boot_default(env : Env) -> Unit {
  try eval(env, load(env, default_script())) |> ignore catch {
    error => abort(error.id())
  }
}

///|
fn default_script() -> String {
  "default: func ['word [word! set-word! lit-word!] value] [\n" +
  "unless all [value? word not none? get word] [set word :value]\n" +
  ":value\n" +
  "]\n"
}

///|
fn boot_constants(env : Env) -> Unit {
  try eval(env, load(env, constants_script())) |> ignore catch {
    error => abort(error.id())
  }
}

///|
fn constants_script() -> String {
  "on: true\n" +
  "off: false\n" +
  "yes: true\n" +
  "no: false\n" +
  "zero: 0\n" +
  "null: #\"^@\"\n" +
  "space: #\" \"\n" +
  "sp: space\n" +
  "backspace: #\"^H\"\n" +
  "bs: backspace\n" +
  "tab: #\"^-\"\n" +
  "newline: #\"^/\"\n" +
  "newpage: #\"^l\"\n" +
  "slash: #\"/\"\n" +
  "backslash: #\"\\\"\n" +
  "escape: #\"^[\"\n" +
  "cr: #\"^M\"\n" +
  "lf: newline\n" +
  "crlf: \"^M^J\"\n" +
  "comma: #\",\"\n" +
  "dot: #\".\"\n" +
  "dbl-quote: #\"^\"\"\n" +
  "whitespace: make bitset! [#\" \" #\"^-\" #\"^/\" #\"^M\"]\n" +
  "q: :quit\n" +
  "!: :not\n" +
  "min: :minimum\n" +
  "max: :maximum\n" +
  "abs: :absolute\n" +
  "empty?: :tail?\n" +
  "---: :comment\n"
}
