///|
/// dirize, undirize, exists?, and size? from the file mezz. clean-path,
/// ask, and list-dir stay out until what-dir and the console prompt exist.
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
  "]\n" +
  "exists?: func [target [file!]] [\n" +
  "info: try [query target]\n" +
  "if (type? info) = object! [info/type]\n" +
  "]\n" +
  "size?: func [target [file!]] [\n" +
  "info: query target\n" +
  "info/size\n" +
  "]\n" +
  "to-rebol-file: func [path [file! string!]] [to-file path]\n" +
  "to-local-file: func [path [file! string!]] [to-string to-file path]\n"
}
