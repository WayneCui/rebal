///|
/// The tail from the last dot, as a file. A slash after that dot, or no
/// dot, is `none`. On a url, `?` and `#` end the name before the search.
fn perform_suffix(path : @value.Cell) -> @value.Cell raise EvalError {
  match path {
    @value.Seq(series, index) if @value.text_series(series.datatype()) => {
      let codes = path_codes(series, index)
      let limit = if series.datatype() == @value.Url {
        url_name_end(codes)
      } else {
        codes.length()
      }
      match last_dot(codes, limit) {
        Some(dot) =>
          if slash_after(codes, dot, limit) {
            @value.None
          } else {
            file_span(codes, dot, limit)
          }
        None => @value.None
      }
    }
    _ => raise EvalError::Cannot("suffix?")
  }
}

///|
fn path_codes(series : @value.Series, index : Int) -> Array[Int] {
  let codes : Array[Int] = []
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.code(cursor) {
      Some(code) => codes.push(code)
      None => ()
    }
    cursor = cursor + 1
  }
  codes
}

///|
fn url_name_end(codes : Array[Int]) -> Int {
  let mut index = 0
  let mut end = codes.length()
  while index < codes.length() && end == codes.length() {
    let code = codes[index]
    if code == '?'.to_int() || code == '#'.to_int() {
      end = index
    }
    index = index + 1
  }
  end
}

///|
fn last_dot(codes : Array[Int], limit : Int) -> Int? {
  let mut index = 0
  let mut found : Int? = None
  let stop = if limit < codes.length() { limit } else { codes.length() }
  while index < stop {
    if codes[index] == '.'.to_int() {
      found = Some(index)
    }
    index = index + 1
  }
  found
}

///|
fn slash_after(codes : Array[Int], dot : Int, limit : Int) -> Bool {
  let mut index = dot + 1
  let mut found = false
  let stop = if limit < codes.length() { limit } else { codes.length() }
  while index < stop && !found {
    if codes[index] == '/'.to_int() {
      found = true
    }
    index = index + 1
  }
  found
}

///|
fn file_span(codes : Array[Int], start : Int, end : Int) -> @value.Cell {
  let series = @value.Series::text_of(@value.File)
  let stop = if end < codes.length() { end } else { codes.length() }
  for index in start..<stop {
    series.push_code(codes[index]) |> ignore
  }
  @value.Seq(series, 0)
}
