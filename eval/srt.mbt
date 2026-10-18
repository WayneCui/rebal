///|
/// SubRip cues, as in codec-srt.reb. The block is `[start end text ...]`.
/// A cue that is not that shape is none.
fn encode_srt(value : @value.Cell) -> @value.Cell raise EvalError {
  match srt_cues(value) {
    Some(text) => text_series(text)
    None => @value.Cell::None
  }
}

///|
fn decode_srt(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, _) if series.datatype() == @value.File =>
      source_text(value)
    _ => string_text(value)
  }
  match srt_read(env, text) {
    Some(block) => block
    None => @value.Cell::None
  }
}

///|
fn srt_cues(value : @value.Cell) -> String? raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let buf = StringBuilder()
      let mut cursor = if index < 0 { 0 } else { index }
      let mut count = 0
      while cursor < series.length() {
        if cursor + 2 >= series.length() {
          return None
        }
        match
          (
            series.item(cursor),
            series.item(cursor + 1),
            series.item(cursor + 2),
          ) {
          (Some(start), Some(finish), Some(line)) =>
            match (start, finish, line) {
              (@value.Time(_), @value.Time(_), @value.Seq(text, text_at)) if text.datatype() ==
                @value.String => {
                count = count + 1
                buf.write_string(count.to_string())
                buf.write_char('\n')
                buf.write_string(@mold.form_text(start))
                buf.write_string(" --> ")
                buf.write_string(@mold.form_text(finish))
                buf.write_char('\n')
                buf.write_string(text_from(text, text_at))
                buf.write_string("\n\n")
              }
              _ => return None
            }
          _ => return None
        }
        cursor = cursor + 3
      }
      Some(buf.to_string())
    }
    _ => None
  }
}

///|
fn srt_read(env : Env, text : String) -> @value.Cell? raise EvalError {
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  let mut at = 0
  while at < codes.length() && srt_space(codes[at]) {
    at = at + 1
  }
  let block = @value.Series::block()
  while at < codes.length() {
    let index_end = srt_digits(codes, at)
    if index_end == at || index_end >= codes.length() || codes[index_end] != 10 {
      return None
    }
    at = index_end + 1
    let start = srt_clock(env, codes, at)
    if start is None {
      return None
    }
    at = start.unwrap().1
    if !srt_arrow(codes, at) {
      return None
    }
    at = at + 5
    let finish = srt_clock(env, codes, at)
    if finish is None {
      return None
    }
    at = finish.unwrap().1
    if at >= codes.length() || codes[at] != 10 {
      return None
    }
    at = at + 1
    let line = srt_line(codes, at)
    if line is None {
      return None
    }
    block.push_item(start.unwrap().0) |> ignore
    block.push_item(finish.unwrap().0) |> ignore
    block.push_item(text_series(line.unwrap().0)) |> ignore
    at = line.unwrap().1
  }
  Some(@value.Seq(block, 0))
}

///|
fn srt_space(code : Int) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn srt_digits(codes : Array[Int], at : Int) -> Int {
  let mut index = at
  while index < codes.length() &&
        codes[index] >= '0'.to_int() &&
        codes[index] <= '9'.to_int() {
    index = index + 1
  }
  index
}

///|
fn srt_arrow(codes : Array[Int], at : Int) -> Bool {
  at + 5 <= codes.length() &&
  codes[at] == ' '.to_int() &&
  codes[at + 1] == '-'.to_int() &&
  codes[at + 2] == '-'.to_int() &&
  codes[at + 3] == '>'.to_int() &&
  codes[at + 4] == ' '.to_int()
}

///|
fn srt_clock(
  env : Env,
  codes : Array[Int],
  at : Int,
) -> (@value.Cell, Int)? raise EvalError {
  let mut index = at
  let buf = StringBuilder()
  while index < codes.length() &&
        codes[index] != ' '.to_int() &&
        codes[index] != 10 {
    let code = if codes[index] == ','.to_int() {
      '.'.to_int()
    } else {
      codes[index]
    }
    match code.to_char() {
      Some(char) => buf.write_char(char)
      None => ()
    }
    index = index + 1
  }
  if buf.to_string() == "" {
    None
  } else {
    match load(env, buf.to_string()) {
      @value.Time(_) as time => Some((time, index))
      @value.Seq(series, _) if series.datatype() == @value.Block &&
        series.length() == 1 =>
        match series.item(0) {
          Some(@value.Time(_) as time) => Some((time, index))
          _ => None
        }
      _ => None
    }
  }
}

///|
fn srt_line(codes : Array[Int], at : Int) -> (String, Int)? {
  let mut index = at
  let buf = StringBuilder()
  while index + 1 < codes.length() {
    if codes[index] == 10 && codes[index + 1] == 10 {
      return Some((buf.to_string(), index + 2))
    }
    match codes[index].to_char() {
      Some(char) => buf.write_char(char)
      None => ()
    }
    index = index + 1
  }
  None
}
