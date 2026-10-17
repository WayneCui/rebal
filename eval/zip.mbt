///|
/// One stored file inside a zip archive.
priv struct ZipPart {
  name : Array[Int]
  data : Array[Int]
  crc : Int64
}

///|
/// `compress block 'zip` stores each `file!` and its text or binary.
/// Refinements are refused. Deflate inside the archive is not used.
fn zip_compress(
  spec : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  if active.length() > 0 {
    raise EvalError::Cannot("compress")
  }
  let items = zip_items(spec)
  if items.length() % 2 != 0 {
    raise EvalError::Cannot("compress")
  }
  let parts : Array[ZipPart] = []
  let mut cursor = 0
  while cursor < items.length() {
    parts.push(zip_part(items[cursor], items[cursor + 1]))
    cursor = cursor + 2
  }
  binary_cell(zip_bytes(parts))
}

///|
fn zip_items(spec : @value.Cell) -> Array[@value.Cell] raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let items : Array[@value.Cell] = []
      for cursor in index..<series.length() {
        match series.item(cursor) {
          Some(item) => items.push(item)
          None => ()
        }
      }
      items
    }
    _ => raise EvalError::Cannot("compress")
  }
}

///|
fn zip_part(name : @value.Cell, data : @value.Cell) -> ZipPart raise EvalError {
  match name {
    @value.Seq(series, index) if series.datatype() == @value.File => {
      let bytes = payload_bytes(data, "compress")
      {
        name: utf8_bytes(text_from(series, index)),
        data: bytes,
        crc: crc32(bytes),
      }
    }
    _ => raise EvalError::Cannot("compress")
  }
}

///|
fn zip_bytes(parts : Array[ZipPart]) -> Array[Int] {
  let out : Array[Int] = []
  let offsets : Array[Int] = []
  for part in parts {
    offsets.push(out.length())
    write_local(out, part)
  }
  let directory = out.length()
  for i in 0..<parts.length() {
    write_central(out, parts[i], offsets[i])
  }
  write_end(out, parts.length(), out.length() - directory, directory)
  out
}

///|
fn write_local(out : Array[Int], part : ZipPart) -> Unit {
  out.push(0x50)
  out.push(0x4B)
  out.push(0x03)
  out.push(0x04)
  push_u16(out, 20)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u32(out, unsigned32(part.crc))
  push_u32(out, part.data.length().to_int64())
  push_u32(out, part.data.length().to_int64())
  push_u16(out, part.name.length())
  push_u16(out, 0)
  for byte in part.name {
    out.push(byte)
  }
  for byte in part.data {
    out.push(byte)
  }
}

///|
fn write_central(out : Array[Int], part : ZipPart, offset : Int) -> Unit {
  out.push(0x50)
  out.push(0x4B)
  out.push(0x01)
  out.push(0x02)
  push_u16(out, 20)
  push_u16(out, 20)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u32(out, unsigned32(part.crc))
  push_u32(out, part.data.length().to_int64())
  push_u32(out, part.data.length().to_int64())
  push_u16(out, part.name.length())
  push_u16(out, 0)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u32(out, 0L)
  push_u32(out, offset.to_int64())
  for byte in part.name {
    out.push(byte)
  }
}

///|
fn write_end(out : Array[Int], count : Int, size : Int, offset : Int) -> Unit {
  out.push(0x50)
  out.push(0x4B)
  out.push(0x05)
  out.push(0x06)
  push_u16(out, 0)
  push_u16(out, 0)
  push_u16(out, count)
  push_u16(out, count)
  push_u32(out, size.to_int64())
  push_u32(out, offset.to_int64())
  push_u16(out, 0)
}

///|
fn push_u16(out : Array[Int], value : Int) -> Unit {
  out.push(value % 256)
  out.push(value / 256 % 256)
}

///|
fn push_u32(out : Array[Int], value : Int64) -> Unit {
  let mut rest = value
  for _ in 0..<4 {
    out.push((rest % 256L).to_int())
    rest = rest / 256L
  }
}

///|
fn unsigned32(sum : Int64) -> Int64 {
  if sum < 0 {
    sum + 0x100000000L
  } else {
    sum
  }
}

///|
fn signed32(sum : Int64) -> Int64 {
  if sum >= 0x80000000L {
    sum - 0x100000000L
  } else {
    sum
  }
}

///|
fn zip_block(bytes : Array[Int]) -> @value.Cell raise EvalError {
  let end = find_eocd(bytes)
  if read_u16(bytes, end + 4) != 0 || read_u16(bytes, end + 6) != 0 {
    raise EvalError::Cannot("decompress")
  }
  let count = read_u16(bytes, end + 8)
  let mut cursor = read_u32(bytes, end + 16).to_int()
  let block = @value.Series::block()
  for _ in 0..<count {
    let (part, next) = read_central(bytes, cursor)
    block.push_item(file_cell(utf8_text(part.name))) |> ignore
    block.push_item(zip_info(part)) |> ignore
    cursor = next
  }
  @value.Seq(block, 0)
}

///|
fn zip_info(part : ZipPart) -> @value.Cell {
  let info = @value.Series::block()
  info.push_item(@value.None) |> ignore
  info.push_item(@value.Integer(part.crc)) |> ignore
  info.push_item(binary_cell(part.data)) |> ignore
  @value.Seq(info, 0)
}

///|
fn find_eocd(bytes : Array[Int]) -> Int raise EvalError {
  if bytes.length() < 22 {
    raise EvalError::Cannot("decompress")
  }
  let mut cursor = bytes.length() - 22
  while cursor >= 0 {
    if bytes[cursor] == 0x50 &&
      bytes[cursor + 1] == 0x4B &&
      bytes[cursor + 2] == 0x05 &&
      bytes[cursor + 3] == 0x06 {
      let comment = read_u16(bytes, cursor + 20)
      if cursor + 22 + comment == bytes.length() {
        return cursor
      }
    }
    cursor = cursor - 1
  }
  raise EvalError::Cannot("decompress")
}

///|
fn read_central(bytes : Array[Int], at : Int) -> (ZipPart, Int) raise EvalError {
  need(bytes, at, 46)
  if bytes[at] != 0x50 ||
    bytes[at + 1] != 0x4B ||
    bytes[at + 2] != 0x01 ||
    bytes[at + 3] != 0x02 {
    raise EvalError::Cannot("decompress")
  }
  if read_u16(bytes, at + 10) != 0 {
    raise EvalError::Cannot("decompress")
  }
  let crc = signed32(read_u32(bytes, at + 16))
  let size = read_u32(bytes, at + 20)
  if read_u32(bytes, at + 24) != size {
    raise EvalError::Cannot("decompress")
  }
  let name_len = read_u16(bytes, at + 28)
  let extra = read_u16(bytes, at + 30)
  let comment = read_u16(bytes, at + 32)
  let offset = read_u32(bytes, at + 42).to_int()
  need(bytes, at + 46, name_len)
  let name = copy_bytes(bytes, at + 46, name_len)
  let data = read_stored(bytes, offset, size)
  (ZipPart::{ name, data, crc, }, at + 46 + name_len + extra + comment)
}

///|
fn read_stored(
  bytes : Array[Int],
  offset : Int,
  size : Int64,
) -> Array[Int] raise EvalError {
  need(bytes, offset, 30)
  if bytes[offset] != 0x50 ||
    bytes[offset + 1] != 0x4B ||
    bytes[offset + 2] != 0x03 ||
    bytes[offset + 3] != 0x04 {
    raise EvalError::Cannot("decompress")
  }
  let name_len = read_u16(bytes, offset + 26)
  let extra = read_u16(bytes, offset + 28)
  let start = offset + 30 + name_len + extra
  let count = size.to_int()
  need(bytes, start, count)
  copy_bytes(bytes, start, count)
}

///|
fn copy_bytes(bytes : Array[Int], at : Int, count : Int) -> Array[Int] {
  let out : Array[Int] = []
  for cursor in at..<(at + count) {
    out.push(bytes[cursor])
  }
  out
}

///|
fn need(bytes : Array[Int], at : Int, count : Int) -> Unit raise EvalError {
  if at < 0 || count < 0 || at + count > bytes.length() {
    raise EvalError::Cannot("decompress")
  }
}

///|
fn read_u16(bytes : Array[Int], at : Int) -> Int raise EvalError {
  need(bytes, at, 2)
  bytes[at] + bytes[at + 1] * 256
}

///|
fn read_u32(bytes : Array[Int], at : Int) -> Int64 raise EvalError {
  need(bytes, at, 4)
  bytes[at].to_int64() +
  bytes[at + 1].to_int64() * 256L +
  bytes[at + 2].to_int64() * 65536L +
  bytes[at + 3].to_int64() * 16777216L
}

///|
fn utf8_text(bytes : Array[Int]) -> String raise EvalError {
  let buf = StringBuilder()
  let mut cursor = 0
  while cursor < bytes.length() {
    let (code, next) = read_utf8(bytes, cursor)
    match code.to_char() {
      Some(char) => buf.write_char(char)
      None => raise EvalError::Cannot("decompress")
    }
    cursor = next
  }
  buf.to_string()
}

///|
fn read_utf8(bytes : Array[Int], at : Int) -> (Int, Int) raise EvalError {
  let lead = bytes[at]
  if lead < 0x80 {
    (lead, at + 1)
  } else if lead < 0xE0 {
    utf8_code(bytes, at, 2, lead % 32)
  } else if lead < 0xF0 {
    utf8_code(bytes, at, 3, lead % 16)
  } else {
    utf8_code(bytes, at, 4, lead % 8)
  }
}

///|
fn utf8_code(
  bytes : Array[Int],
  at : Int,
  width : Int,
  lead : Int,
) -> (Int, Int) raise EvalError {
  if at + width > bytes.length() {
    raise EvalError::Cannot("decompress")
  }
  let mut code = lead
  for cursor in (at + 1)..<(at + width) {
    let byte = bytes[cursor]
    if byte < 0x80 || byte >= 0xC0 {
      raise EvalError::Cannot("decompress")
    }
    code = code * 64 + byte % 64
  }
  (code, at + width)
}
