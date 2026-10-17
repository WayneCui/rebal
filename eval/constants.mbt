///|
/// The boot constants from base-constants. `system` is not built yet, so
/// `REBOL`, `sys`, and `lib` stay as they were installed.
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
