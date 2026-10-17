///|
#borrow(path)
extern "C" fn c_list_dir(path : String, path_len : Int) -> String = "rebal_list_dir"

///|
#borrow(path)
extern "C" fn c_make_dir(path : String, path_len : Int) -> Int = "rebal_make_dir"

///|
pub fn make_dir(path : String) -> Unit raise EvalError {
  if c_make_dir(path, path.length()) == 0 {
    ()
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
/// `read` returns one file! for each entry. A directory's name ends in `/`.
/// `.` and `..` are left out. `write` is refused.
fn dir_actor(
  env : Env,
  action : String,
  port : @value.Cell,
  extra : @value.Cell?,
) -> @value.Cell raise EvalError {
  let _ = extra
  match action {
    "open" => {
      set_port_open(port, true)
      port
    }
    "close" => {
      set_port_open(port, false)
      port
    }
    "read" => dir_list(env, port)
    "query" => dir_query(env, port)
    _ => raise EvalError::Cannot("port")
  }
}

///|
fn dir_list(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let text = list_dir(port_path(env, port))
  let names = split_lines(text)
  sort_names(names)
  let block = @value.Series::block()
  for name in names {
    block.push_item(file_cell(name)) |> ignore
  }
  @value.Seq(block, 0)
}

///|
fn dir_query(env : Env, port : @value.Cell) -> @value.Cell raise EvalError {
  let _ = list_dir(port_path(env, port))
  let info = @value.Frame::new()
  put_field(env, info, "name", port_ref(env, port))
  put_field(env, info, "size", @value.None)
  put_field(env, info, "type", word_cell(env, "dir"))
  @value.Object(info)
}

///|
fn list_dir(path : String) -> String raise EvalError {
  let text = c_list_dir(path, path.length())
  if c_io_status() == 0 {
    text
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
fn sort_names(names : Array[String]) -> Unit {
  let mut i = 1
  while i < names.length() {
    let mut j = i
    while j > 0 && text_before(names[j], names[j - 1]) {
      let later = names[j]
      names[j] = names[j - 1]
      names[j - 1] = later
      j = j - 1
    }
    i = i + 1
  }
}

///|
fn text_before(left : String, right : String) -> Bool {
  let mut index = 0
  while index < left.length() && index < right.length() {
    let left_code = left[index].to_int()
    let right_code = right[index].to_int()
    if left_code != right_code {
      return left_code < right_code
    }
    index = index + 1
  }
  left.length() < right.length()
}

///|
fn split_lines(text : String) -> Array[String] {
  let names : Array[String] = []
  if text.length() == 0 {
    names
  } else {
    let mut start = 0
    let mut index = 0
    while index <= text.length() {
      if index == text.length() || text[index] == '\n' {
        names.push(text[start:index].to_owned())
        start = index + 1
      }
      index = index + 1
    }
    names
  }
}

///|
fn file_cell(text : String) -> @value.Cell {
  let series = @value.Series::text_of(@value.File)
  for char in text {
    series.push_code(char.to_int()) |> ignore
  }
  @value.Seq(series, 0)
}
