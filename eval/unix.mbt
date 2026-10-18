///|
/// Unix time, as in codec-unixtime.reb. A zoned clock is converted to UTC.
/// Decode stamps the result with the local zone from `now/zone`.
fn encode_unix(
  value : @value.Cell,
  form : @value.Cell?,
) -> @value.Cell raise EvalError {
  let epoch = match value {
    @value.Date(date) => unix_epoch(date)
    _ => raise EvalError::Cannot("encode")
  }
  match form {
    None => @value.Integer(epoch)
    Some(kind) =>
      match unix_kind(kind) {
        "integer" => @value.Integer(epoch)
        "binary" => binary_cell(unix_bytes(epoch))
        "string" => text_series(unix_hex(unix_bytes(epoch)))
        _ => raise EvalError::Cannot("encode")
      }
  }
}

///|
fn decode_unix(value : @value.Cell) -> @value.Cell raise EvalError {
  let epoch = match value {
    @value.Integer(n) => Some(n)
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      unix_be(bytes_from(series, index))
    @value.Seq(series, index) if @value.text_series(series.datatype()) =>
      unix_hex_int(text_from(series, index))
    _ => raise EvalError::Cannot("decode")
  }
  match epoch {
    None => @value.None
    Some(seconds) => @value.Date(unix_local(seconds))
  }
}

///|
fn unix_epoch(date : @value.DateValue) -> Int64 {
  let origin = @value.DateValue::make(1970, 1, 1, None, None)
  let mut seconds = date.day_diff(origin).to_int64() * 86400L
  match date.time() {
    Some(clock) => seconds = seconds + clock.to_int64()
    None => ()
  }
  match date.zone() {
    Some(minutes) => seconds - minutes.to_int64() * 60L
    None => seconds
  }
}

///|
fn unix_local(epoch : Int64) -> @value.DateValue {
  let utc = unix_date(epoch)
  let zone = c_clock_zone()
  let shifted = utc.add_seconds(zone.to_double() * 60.0)
  @value.DateValue::make(
    shifted.year(),
    shifted.month(),
    shifted.day(),
    shifted.time(),
    Some(zone),
  )
}

///|
fn unix_date(epoch : Int64) -> @value.DateValue {
  let mut days = epoch / 86400L
  let mut rest = epoch % 86400L
  if rest < 0L {
    rest = rest + 86400L
    days = days - 1L
  }
  let base = @value.DateValue::make(1970, 1, 1, Some(rest.to_double()), None)
  base.shift(days.to_int())
}

///|
fn unix_bytes(epoch : Int64) -> Array[Int] {
  let mut value = epoch % 4294967296L
  if value < 0L {
    value = value + 4294967296L
  }
  [
    (value / 16777216L).to_int(),
    (value / 65536L % 256L).to_int(),
    (value / 256L % 256L).to_int(),
    (value % 256L).to_int(),
  ]
}

///|
fn unix_hex(bytes : Array[Int]) -> String {
  let buf = StringBuilder()
  for byte in bytes {
    buf.write_char(hex_digit(byte / 16))
    buf.write_char(hex_digit(byte % 16))
  }
  buf.to_string()
}

///|
fn unix_hex_int(text : String) -> Int64? {
  unix_be(decode_base16(text)) catch {
    _ => None
  }
}

///|
fn unix_be(bytes : Array[Int]) -> Int64? {
  if bytes.length() == 0 || bytes.length() > 8 {
    None
  } else {
    let mut value = 0L
    for byte in bytes {
      value = value * 256L + byte.to_int64()
    }
    Some(value)
  }
}

///|
fn unix_kind(value : @value.Cell) -> String {
  match value {
    @value.Type(@value.Integer) => "integer"
    @value.Type(@value.Binary) => "binary"
    @value.Type(@value.String) => "string"
    _ => ""
  }
}
