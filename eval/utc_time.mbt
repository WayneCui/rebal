///|
/// ASN.1 UTCTime, the way the Rebol codec reads it.
/// The two-digit year is always placed in 2000–2099.
fn decode_utc_time(value : @value.Cell) -> @value.Cell raise EvalError {
  let text = latin_text(payload_bytes(value, "decode"))
  match read_utc(text) {
    Some(date) => @value.Date(date)
    None => @value.None
  }
}

///|
fn read_utc(text : String) -> @value.DateValue? {
  match
    (
      utc_pair(text, 0),
      utc_pair(text, 2),
      utc_pair(text, 4),
      utc_pair(text, 6),
      utc_pair(text, 8),
    ) {
    (Some(year), Some(month), Some(day), Some(hour), Some(minute)) =>
      if month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31 &&
        hour <= 23 &&
        minute <= 59 {
        read_utc_tail(text, 10, 2000 + year, month, day, hour, minute)
      } else {
        None
      }
    _ => None
  }
}

///|
fn read_utc_tail(
  text : String,
  at : Int,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
) -> @value.DateValue? {
  let mut cursor = at
  let mut second = 0
  match utc_pair(text, cursor) {
    Some(found) => {
      let marker = cursor + 2
      if found <= 59 && (marker >= text.length() || utc_mark(text, marker)) {
        second = found
        cursor = marker
      }
    }
    None => ()
  }
  let seconds = hour.to_double() * 3600.0 +
    minute.to_double() * 60.0 +
    second.to_double()
  if cursor < text.length() &&
    text[cursor].to_int() == 90 &&
    cursor + 1 == text.length() {
    Some(@value.DateValue::make(year, month, day, Some(seconds), None))
  } else if cursor < text.length() &&
    (text[cursor].to_int() == 43 || text[cursor].to_int() == 45) {
    let sign = if text[cursor].to_int() == 45 { -1 } else { 1 }
    match (utc_pair(text, cursor + 1), utc_pair(text, cursor + 3)) {
      (Some(zone_hour), Some(zone_minute)) =>
        if zone_hour <= 23 && zone_minute <= 59 && cursor + 5 == text.length() {
          Some(
            @value.DateValue::make(
              year,
              month,
              day,
              Some(seconds),
              Some(sign * (zone_hour * 60 + zone_minute)),
            ),
          )
        } else {
          None
        }
      _ => None
    }
  } else {
    None
  }
}

///|
fn utc_mark(text : String, at : Int) -> Bool {
  let code = text[at].to_int()
  code == 90 || code == 43 || code == 45
}

///|
fn utc_pair(text : String, at : Int) -> Int? {
  if at + 1 >= text.length() {
    None
  } else {
    let high = text[at].to_int()
    let low = text[at + 1].to_int()
    if high < 48 || high > 57 || low < 48 || low > 57 {
      None
    } else {
      Some((high - 48) * 10 + (low - 48))
    }
  }
}
