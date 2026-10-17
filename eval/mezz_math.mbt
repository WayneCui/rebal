///|
/// sign?, sum, and average from mezz-math. find-min and find-max need
/// forskip, which is not implemented.
fn boot_math(env : Env) -> Unit {
  try eval(env, load(env, math_script())) |> ignore catch {
    error => abort(error.id())
  }
}

///|
fn math_script() -> String {
  "sign?: func [number] [\n" +
  "case [\n" +
  "positive? number [1]\n" +
  "negative? number [-1]\n" +
  "true [0]\n" +
  "]\n" +
  "]\n" +
  "sum: func [values] [\n" +
  "result: 0\n" +
  "foreach value values [result: result + value]\n" +
  "result\n" +
  "]\n" +
  "average: func [block] [\n" +
  "if empty? block [return none]\n" +
  "(sum block) / length? block\n" +
  "]\n"
}
