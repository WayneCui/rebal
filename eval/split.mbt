///|
/// Splits a path into the directory and the last name.
/// A bare file gets `%./`. A name of `.` or `..` keeps its trailing slash.
/// `/`, `.`, and `..` are directories with an empty name.
fn perform_split_path(target : @value.Cell) -> @value.Cell raise EvalError {
  match target {
    @value.Seq(series, index) if @value.text_series(series.datatype()) => {
      let codes = path_codes(series, index)
      let dir = if root_mark(codes) {
        dirized(series.datatype(), codes)
      } else {
        let cut = name_cut(codes)
        if cut == 0 {
          text_of_codes(@value.File, ['.'.to_int(), '/'.to_int()], 0, 2)
        } else {
          text_of_codes(series.datatype(), codes, 0, cut)
        }
      }
      let name = if root_mark(codes) {
        text_of_codes(@value.File, [], 0, 0)
      } else {
        named_file(codes, name_cut(codes))
      }
      let block = @value.Series::block()
      block.push_item(dir) |> ignore
      block.push_item(name) |> ignore
      @value.Seq(block, 0)
    }
    _ => raise EvalError::Cannot("split-path")
  }
}

///|
fn root_mark(codes : Array[Int]) -> Bool {
  let mut end = codes.length()
  if end > 1 && codes[end - 1] == '/'.to_int() {
    end = end - 1
  }
  if end == 1 && (codes[0] == '/'.to_int() || codes[0] == '.'.to_int()) {
    true
  } else if end == 2 && codes[0] == '.'.to_int() && codes[1] == '.'.to_int() {
    true
  } else {
    false
  }
}

///|
fn name_cut(codes : Array[Int]) -> Int {
  let mut pos = 0
  let mut index = 0
  let mut running = true
  while running && index < codes.length() {
    if codes[index] == '/'.to_int() {
      let after = index + 1
      if after == codes.length() {
        running = false
      } else {
        pos = after
        index = after
      }
    } else {
      index = index + 1
    }
  }
  pos
}

///|
fn dirized(datatype : @value.Datatype, codes : Array[Int]) -> @value.Cell {
  let cell = text_of_codes(datatype, codes, 0, codes.length())
  match cell {
    @value.Seq(series, _) =>
      if codes.length() == 0 || codes[codes.length() - 1] != '/'.to_int() {
        series.push_code('/'.to_int()) |> ignore
        cell
      } else {
        cell
      }
    _ => cell
  }
}

///|
fn named_file(codes : Array[Int], start : Int) -> @value.Cell {
  let series = @value.Series::text_of(@value.File)
  for index in start..<codes.length() {
    series.push_code(codes[index]) |> ignore
  }
  let count = codes.length() - start
  let one_dot = count == 1 && codes[start] == '.'.to_int()
  let two_dots = count == 2 &&
    codes[start] == '.'.to_int() &&
    codes[start + 1] == '.'.to_int()
  let dotted = one_dot || two_dots
  if dotted {
    series.push_code('/'.to_int()) |> ignore
  }
  @value.Seq(series, 0)
}

///|
fn text_of_codes(
  datatype : @value.Datatype,
  codes : Array[Int],
  start : Int,
  end : Int,
) -> @value.Cell {
  let series = @value.Series::text_of(datatype)
  for index in start..<end {
    series.push_code(codes[index]) |> ignore
  }
  @value.Seq(series, 0)
}
