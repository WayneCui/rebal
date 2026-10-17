///|
/// dirize and undirize from the file mezz. clean-path, ask, and list-dir
/// stay out until what-dir and the console prompt exist.
fn boot_files(env : Env) -> Unit {
  try eval(env, load(env, files_script())) |> ignore catch {
    error => abort(error.id())
  }
}

///|
fn files_script() -> String {
  "dirize: func [path [file! string! url!]] [\n" +
  "path: copy path\n" +
  "if slash <> last path [append path slash]\n" +
  "path\n" +
  "]\n" +
  "undirize: func [path [file! string! url!]] [\n" +
  "path: copy path\n" +
  "if #\"/\" = last path [clear back tail path]\n" +
  "path\n" +
  "]\n"
}
