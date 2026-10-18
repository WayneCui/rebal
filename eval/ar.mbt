///|
/// Unix `ar` members, as in codec-ar.reb. The block is
/// `[name [date uid gid mode data] ...]`. A missing `!<arch>` header or a
/// broken member is none. Long BSD and GNU names are left as written.
fn decode_ar(value : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = payload_bytes(value, "decode")
  if !ar_magic(bytes) {
    @value.Cell::None
  } else {
    match ar_members(bytes, 8) {
      Some(items) => {
        let block = @value.Series::block()
        for item in items {
          block.push_item(item) |> ignore
        }
        @value.Seq(block, 0)
      }
      None => @value.Cell::None
    }
  }
}

///|
fn ar_members(bytes : Array[Int], start : Int) -> Array[@value.Cell]? {
  let items : Array[@value.Cell] = []
  let mut at = start
  let mut ok = true
  while ok && at < bytes.length() {
    if at + 60 > bytes.length() {
      ok = false
    } else if bytes[at + 58] != 0x60 || bytes[at + 59] != 10 {
      ok = false
    } else {
      let name = ar_trim(ar_field(bytes, at, 16))
      let stamp = ar_int(ar_trim(ar_field(bytes, at + 16, 12)))
      let uid = ar_int(ar_trim(ar_field(bytes, at + 28, 6)))
      let gid = ar_int(ar_trim(ar_field(bytes, at + 34, 6)))
      let mode = ar_int(ar_trim(ar_field(bytes, at + 40, 8)))
      let size = ar_int(ar_trim(ar_field(bytes, at + 48, 10)))
      let mut data_at = at + 60
      if size < 0L || data_at + size.to_int() > bytes.length() {
        ok = false
      } else {
        let data = tar_copy(bytes, data_at, size.to_int())
        data_at = data_at + size.to_int()
        if size % 2L != 0L {
          if data_at >= bytes.length() {
            ok = false
          } else {
            data_at = data_at + 1
          }
        }
        if ok {
          items.push(tar_file(name))
          items.push(ar_info(stamp, uid, gid, mode, data))
          at = data_at
        }
      }
    }
  }
  if ok {
    Some(items)
  } else {
    None
  }
}

///|
fn ar_info(
  stamp : Int64,
  uid : Int64,
  gid : Int64,
  mode : Int64,
  data : Array[Int],
) -> @value.Cell {
  let info = @value.Series::block()
  if stamp <= 0L {
    info.push_item(@value.Cell::None) |> ignore
  } else {
    info.push_item(@value.Date(unix_date(stamp))) |> ignore
  }
  info.push_item(@value.Integer(uid)) |> ignore
  info.push_item(@value.Integer(gid)) |> ignore
  info.push_item(@value.Integer(mode)) |> ignore
  info.push_item(binary_cell(data)) |> ignore
  @value.Seq(info, 0)
}

///|
fn ar_field(bytes : Array[Int], at : Int, width : Int) -> String {
  let buf = StringBuilder()
  for index in 0..<width {
    match bytes[at + index].to_char() {
      Some(char) => buf.write_char(char)
      None => ()
    }
  }
  buf.to_string()
}

///|
fn ar_trim(text : String) -> String {
  let mut end = 0
  for char in text {
    let _ = char
    end = end + 1
  }
  while end > 0 && text[end - 1].to_int() == 32 {
    end = end - 1
  }
  text[0:end].to_owned()
}

///|
fn ar_int(text : String) -> Int64 {
  let mut value = 0L
  let mut digits = false
  let mut bad = false
  let mut negative = false
  let mut started = false
  for char in text {
    let code = char.to_int()
    if !started && code == '-'.to_int() {
      negative = true
      started = true
    } else if code >= '0'.to_int() && code <= '9'.to_int() {
      digits = true
      started = true
      value = value * 10L + (code - '0'.to_int()).to_int64()
    } else {
      bad = true
    }
  }
  if bad || !digits {
    0L
  } else if negative {
    0L - value
  } else {
    value
  }
}
