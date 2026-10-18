///|
/// Windows icon and cursor directories, as in codec-ico.reb. Each image is
/// `[width bpp data]`. A zero width stands for 256. There is no encoder.
fn decode_ico(value : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      bytes_from(series, index)
    _ => raise EvalError::Cannot("decode")
  }
  match ico_icons(bytes) {
    Some(icons) => {
      let block = @value.Series::block()
      for icon in icons {
        block.push_item(icon) |> ignore
      }
      @value.Seq(block, 0)
    }
    None => @value.Cell::None
  }
}

///|
fn ico_icons(bytes : Array[Int]) -> Array[@value.Cell]? {
  if bytes.length() < 6 || ico_u16(bytes, 0) != 0 {
    return None
  }
  let kind = ico_u16(bytes, 2)
  if kind != 1 && kind != 2 {
    return None
  }
  let count = ico_u16(bytes, 4)
  if bytes.length() < 6 + count * 16 {
    return None
  }
  let icons : Array[@value.Cell] = []
  let mut index = 0
  let mut ok = true
  while ok && index < count {
    let at = 6 + index * 16
    let mut width = bytes[at]
    if width == 0 {
      width = 256
    }
    let bpp = ico_u16(bytes, at + 6)
    let size = ico_u32(bytes, at + 8)
    let offset = ico_u32(bytes, at + 12)
    if size < 0L ||
      offset < 0L ||
      offset > bytes.length().to_int64() ||
      size > bytes.length().to_int64() - offset {
      ok = false
    } else {
      let info = @value.Series::block()
      info.push_item(@value.Integer(width.to_int64())) |> ignore
      info.push_item(@value.Integer(bpp.to_int64())) |> ignore
      info.push_item(
        binary_cell(tar_copy(bytes, offset.to_int(), size.to_int())),
      )
      |> ignore
      icons.push(@value.Seq(info, 0))
      index = index + 1
    }
  }
  if ok {
    Some(icons)
  } else {
    None
  }
}

///|
fn ico_u16(bytes : Array[Int], at : Int) -> Int {
  bytes[at] + bytes[at + 1] * 256
}

///|
fn ico_u32(bytes : Array[Int], at : Int) -> Int64 {
  bytes[at].to_int64() +
  bytes[at + 1].to_int64() * 256L +
  bytes[at + 2].to_int64() * 65536L +
  bytes[at + 3].to_int64() * 16777216L
}
