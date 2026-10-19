///|
/// The series helpers that do not need append-into-string, object update,
/// or the format dialect. replace, reword, move, extract, and format stay out.
/// rejoin appends the formed items one by one, which matches append-into-string.
fn boot_series_helpers(env : Env) -> Unit {
  try eval(env, load(env, series_helpers_script())) |> ignore catch {
    error => abort(error.id())
  }
}

///|
fn series_helpers_script() -> String {
  "empty?: func [value] [either none? :value [true] [tail? value]]\n" +
  "offset?: func [series1 series2] [\n" +
  "(index? series2) - (index? series1)\n" +
  "]\n" +
  "last?: func [series] [1 = length? series]\n" +
  "single?: :last?\n" +
  "charset: func [chars] [make bitset! chars]\n" +
  "remold: func [value] [mold reduce :value]\n" +
  "rejoin: func [block [block!] /local out] [\n" +
  "if empty? block: reduce block [return block]\n" +
  "out: either series? block/1 [copy block/1] [form block/1]\n" +
  "foreach item next block [append out form item]\n" +
  "out\n" +
  "]\n"
}
