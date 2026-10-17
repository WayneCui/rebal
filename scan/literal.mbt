///|
fn Lexer::number(self : Lexer) -> Result[@value.Cell, ScanError] {
  let mut sign = 1L
  match self.peek() {
    Some('+') => self.bump() |> ignore
    Some('-') => {
      sign = -1L
      self.bump() |> ignore
    }
    _ => ()
  }
  let whole = self.digits(10)
  if whole.length() == 0 {
    return Err(Invalid("integer"))
  }
  match self.peek() {
    Some('#') =>
      if sign < 0L {
        Err(Invalid("integer"))
      } else if self.chars.get(self.pos + 1) is Some('{') {
        self.bump() |> ignore
        match finish_u64(whole, 10) {
          Some(base) if base == 2UL || base == 16UL =>
            self.binary(base.to_int())
          _ => Err(Invalid("binary"))
        }
      } else {
        self.base_integer(whole)
      }
    Some('.') =>
      match self.chars.get(self.pos + 1) {
        Some(char) if is_digit(char) => self.decimal(sign, whole)
        _ => self.percent_suffix(finish_integer(sign, whole, 10))
      }
    Some(':') =>
      match self.chars.get(self.pos + 1) {
        Some(char) if is_digit(char) => self.time_value(sign, whole)
        _ => self.percent_suffix(finish_integer(sign, whole, 10))
      }
    Some('-') if sign >= 0L =>
      match self.chars.get(self.pos + 1) {
        Some(char) if is_digit(char) || is_letter(char) => {
          let saved = self.pos
          match self.date_try(whole) {
            Ready(cell) => Ok(cell)
            Fail => Err(Invalid("date"))
            Skip => {
              self.pos = saved
              self.percent_suffix(finish_integer(sign, whole, 10))
            }
          }
        }
        _ => self.percent_suffix(finish_integer(sign, whole, 10))
      }
    _ => self.percent_suffix(finish_integer(sign, whole, 10))
  }
}

///|
/// `1:30` is one hour and thirty minutes. `1:30.5` is one minute and 30.5 seconds.
fn Lexer::time_value(
  self : Lexer,
  sign : Int64,
  hours : Array[Int],
) -> Result[@value.Cell, ScanError] {
  match signed(hours, 10, 1L) {
    None => Err(Invalid("time"))
    Some(hour) => {
      self.bump() |> ignore
      let minutes = self.digits(10)
      match signed(minutes, 10, 1L) {
        None => Err(Invalid("time"))
        Some(minute) => self.finish_clock(sign, hour, minute)
      }
    }
  }
}

///|
fn Lexer::finish_clock(
  self : Lexer,
  sign : Int64,
  hour : Int64,
  minute : Int64,
) -> Result[@value.Cell, ScanError] {
  let signed_by = sign.to_double()
  match self.peek() {
    Some(':') =>
      match self.chars.get(self.pos + 1) {
        Some(char) if is_digit(char) => {
          self.bump() |> ignore
          match self.second_value() {
            None => Err(Invalid("time"))
            Some(second) =>
              Ok(
                @value.Time(
                  @value.snap_seconds(
                    signed_by *
                    (
                      hour.to_double() * 3600.0 +
                      minute.to_double() * 60.0 +
                      second
                    ),
                  ),
                ),
              )
          }
        }
        _ => Err(Invalid("time"))
      }
    Some('.') =>
      match self.chars.get(self.pos + 1) {
        Some(char) if is_digit(char) => {
          self.bump() |> ignore
          let fraction = fraction_value(self.digits(10))
          Ok(
            @value.Time(
              @value.snap_seconds(
                signed_by *
                (hour.to_double() * 60.0 + minute.to_double() + fraction),
              ),
            ),
          )
        }
        _ =>
          Ok(
            @value.Time(
              @value.snap_seconds(
                signed_by *
                (hour.to_double() * 3600.0 + minute.to_double() * 60.0),
              ),
            ),
          )
      }
    _ =>
      Ok(
        @value.Time(
          @value.snap_seconds(
            signed_by * (hour.to_double() * 3600.0 + minute.to_double() * 60.0),
          ),
        ),
      )
  }
}

///|
fn Lexer::second_value(self : Lexer) -> Double? {
  match signed(self.digits(10), 10, 1L) {
    None => None
    Some(whole) =>
      match self.peek() {
        Some('.') =>
          match self.chars.get(self.pos + 1) {
            Some(char) if is_digit(char) => {
              self.bump() |> ignore
              Some(whole.to_double() + fraction_value(self.digits(10)))
            }
            _ => Some(whole.to_double())
          }
        _ => Some(whole.to_double())
      }
  }
}

///|
fn fraction_value(digits : Array[Int]) -> Double {
  let mut value = 0.0
  let mut place = 0.1
  for digit in digits {
    value = value + digit.to_double() * place
    place = place / 10.0
  }
  value
}

///|
fn Lexer::base_integer(
  self : Lexer,
  base_digits : Array[Int],
) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  match finish_u64(base_digits, 10) {
    None => Err(Invalid("integer"))
    Some(base) =>
      if base == 0UL {
        self.percent_suffix(finish_integer(1L, self.digits(16), 16))
      } else if base == 2UL || base == 8UL || base == 10UL || base == 16UL {
        match self.strict_digits(base.to_int()) {
          Ok(digits) =>
            self.percent_suffix(finish_integer(1L, digits, base.to_int()))
          Err(error) => Err(error)
        }
      } else {
        Err(Invalid("integer"))
      }
  }
}

///|
fn finish_integer(
  sign : Int64,
  digits : Array[Int],
  base : Int,
) -> Result[@value.Cell, ScanError] {
  if digits.length() == 0 {
    Err(Invalid("integer"))
  } else {
    match signed(digits, base, sign) {
      Some(value) => Ok(@value.Cell::Integer(value))
      None => Err(Invalid("integer"))
    }
  }
}

///|
fn Lexer::decimal(
  self : Lexer,
  sign : Int64,
  whole : Array[Int],
) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  let frac = self.digits(10)
  let mut value = 0.0
  for digit in whole {
    value = value * 10.0 + digit.to_double()
  }
  let mut place = 0.1
  for digit in frac {
    value = value + digit.to_double() * place
    place = place / 10.0
  }
  if sign < 0L {
    self.percent_suffix(Ok(@value.Cell::Decimal(value * sign.to_double())))
  } else if self.tuple_more() {
    self.tuple_value(whole, frac)
  } else {
    self.percent_suffix(Ok(@value.Cell::Decimal(value * sign.to_double())))
  }
}

///|
fn Lexer::tuple_more(self : Lexer) -> Bool {
  match self.peek() {
    Some('.') =>
      match self.chars.get(self.pos + 1) {
        Some(char) => is_digit(char)
        None => false
      }
    _ => false
  }
}

///|
fn Lexer::tuple_value(
  self : Lexer,
  whole : Array[Int],
  frac : Array[Int],
) -> Result[@value.Cell, ScanError] {
  match (byte_component(whole), byte_component(frac)) {
    (Some(first), Some(second)) => {
      let parts : Array[Int] = [first, second]
      let mut bad = false
      while !bad && self.tuple_more() {
        self.bump() |> ignore
        match byte_component(self.digits(10)) {
          Some(part) => parts.push(part)
          None => bad = true
        }
      }
      if bad || parts.length() > 12 {
        Err(Invalid("tuple"))
      } else {
        Ok(@value.Tuple(parts))
      }
    }
    _ => Err(Invalid("tuple"))
  }
}

///|
fn byte_component(digits : Array[Int]) -> Int? {
  if digits.length() == 0 || digits.length() > 3 {
    None
  } else {
    let mut value = 0
    for digit in digits {
      value = value * 10 + digit
    }
    if value > 255 {
      None
    } else {
      Some(value)
    }
  }
}

///|
fn Lexer::percent_suffix(
  self : Lexer,
  cell : Result[@value.Cell, ScanError],
) -> Result[@value.Cell, ScanError] {
  match cell {
    Ok(value) =>
      match self.peek() {
        Some('%') => {
          self.bump() |> ignore
          match value {
            @value.Integer(n) => Ok(@value.Percent(n.to_double() / 100.0))
            @value.Decimal(n) => Ok(@value.Percent(n / 100.0))
            _ => Ok(value)
          }
        }
        Some('x') | Some('X') =>
          match value {
            @value.Integer(n) if self.pair_tail() => {
              self.bump() |> ignore
              match self.number() {
                Ok(@value.Integer(m)) => Ok(@value.Pair(n, m))
                Ok(_) => Err(Invalid("pair"))
                Err(error) => Err(error)
              }
            }
            _ => Ok(value)
          }
        _ => Ok(value)
      }
    Err(error) => Err(error)
  }
}

///|
fn Lexer::pair_tail(self : Lexer) -> Bool {
  match self.chars.get(self.pos + 1) {
    Some(char) => is_digit(char) || char == '+' || char == '-'
    None => false
  }
}

///|
fn Lexer::strict_digits(
  self : Lexer,
  base : Int,
) -> Result[Array[Int], ScanError] {
  let out : Array[Int] = []
  let mut bad = false
  let mut reading = true
  while reading {
    match self.peek() {
      Some(char) =>
        match digit_value(char) {
          Some(value) if value < base => {
            self.bump() |> ignore
            out.push(value)
          }
          Some(_) => {
            bad = true
            reading = false
          }
          None => reading = false
        }
      None => reading = false
    }
  }
  if bad {
    Err(Invalid("integer"))
  } else {
    Ok(out)
  }
}

///|
fn Lexer::digits(self : Lexer, base : Int) -> Array[Int] {
  let out : Array[Int] = []
  while (match self.peek() {
          Some(char) =>
            match digit_value(char) {
              Some(value) => value < base
              None => false
            }
          None => false
        }) {
    match self.bump() {
      Some(char) =>
        match digit_value(char) {
          Some(value) => out.push(value)
          None => ()
        }
      None => ()
    }
  }
  out
}

///|
fn digit_value(char : Char) -> Int? {
  if char >= '0' && char <= '9' {
    Some(char.to_int() - '0'.to_int())
  } else if char >= 'A' && char <= 'F' {
    Some(char.to_int() - 'A'.to_int() + 10)
  } else if char >= 'a' && char <= 'f' {
    Some(char.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn signed(digits : Array[Int], base : Int, sign : Int64) -> Int64? {
  match finish_u64(digits, base) {
    None => None
    Some(value) =>
      if sign < 0L {
        if value == 0UL {
          Some(0L)
        } else if value <= 9223372036854775808UL {
          Some(value.reinterpret_as_int64() * -1L)
        } else {
          None
        }
      } else if value <= 9223372036854775807UL {
        Some(value.reinterpret_as_int64())
      } else if value == 18446744073709551615UL {
        Some(value.reinterpret_as_int64())
      } else {
        None
      }
  }
}

///|
fn finish_u64(digits : Array[Int], base : Int) -> UInt64? {
  let mut value = 0UL
  let base64 = base.to_uint64()
  for digit in digits {
    let piece = digit.to_uint64()
    if value > (18446744073709551615UL - piece) / base64 {
      return None
    }
    value = value * base64 + piece
  }
  Some(value)
}

///|
fn Lexer::string(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  let series = @value.Series::text()
  let mut result : Result[@value.Cell, ScanError] = Err(Missing("\""))
  let mut open = true
  while open {
    match self.bump() {
      None => open = false
      Some('"') => {
        result = Ok(@value.Seq(series, 0))
        open = false
      }
      Some('^') =>
        match self.caret() {
          Ok(code) => series.push_code(code) |> ignore
          Err(error) => {
            result = Err(error)
            open = false
          }
        }
      Some(char) => series.push_code(char.to_int()) |> ignore
    }
  }
  result
}

///|
fn Lexer::braced(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  let series = @value.Series::text()
  let mut depth = 1
  let mut result : Result[@value.Cell, ScanError] = Err(Missing("}"))
  while depth > 0 {
    match self.bump() {
      None => depth = 0
      Some('{') => {
        depth = depth + 1
        series.push_code('{'.to_int()) |> ignore
      }
      Some('}') =>
        if depth == 1 {
          depth = 0
          result = Ok(@value.Seq(series, 0))
        } else {
          depth = depth - 1
          series.push_code('}'.to_int()) |> ignore
        }
      Some(char) => series.push_code(char.to_int()) |> ignore
    }
  }
  result
}

///|
fn Lexer::hash(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  match self.peek() {
    Some('"') => self.char_literal()
    Some('{') => self.binary(16)
    Some(char) if is_digit(char) => self.based_binary()
    Some(char) if is_word_char(char) => self.issue()
    _ => Err(Invalid("hash"))
  }
}

///|
fn Lexer::char_literal(self : Lexer) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  let code = match self.peek() {
    Some('^') => {
      self.bump() |> ignore
      self.caret()
    }
    Some(char) => {
      self.bump() |> ignore
      Ok(char.to_int())
    }
    None => Err(Missing("\""))
  }
  match code {
    Err(error) => Err(error)
    Ok(value) =>
      match self.bump() {
        Some('"') => Ok(@value.Cell::Char(value))
        _ => Err(Missing("\""))
      }
  }
}

///|
fn Lexer::caret(self : Lexer) -> Result[Int, ScanError] {
  match self.bump() {
    Some('(') => {
      let digits = self.digits(16)
      match self.bump() {
        Some(')') =>
          match signed(digits, 16, 1L) {
            Some(code) if code >= 0L && code <= 0x10FFFFL => Ok(code.to_int())
            _ => Err(Invalid("char"))
          }
        _ => Err(Missing(")"))
      }
    }
    Some(char) if char >= 'A' && char <= 'Z' =>
      Ok(char.to_int() - 'A'.to_int() + 1)
    Some(char) if char >= 'a' && char <= 'z' =>
      Ok(char.to_int() - 'a'.to_int() + 1)
    Some('/') => Ok('\n'.to_int())
    Some('-') => Ok('\t'.to_int())
    Some('"') => Ok('"'.to_int())
    Some('^') => Ok('^'.to_int())
    Some('}') => Ok('}'.to_int())
    _ => Err(Invalid("char"))
  }
}

///|
fn Lexer::based_binary(self : Lexer) -> Result[@value.Cell, ScanError] {
  let base_digits = self.digits(10)
  match self.peek() {
    Some('#') => self.bump() |> ignore
    _ => return Err(Invalid("binary"))
  }
  match finish_u64(base_digits, 10) {
    Some(base) if base == 2UL || base == 16UL =>
      match self.peek() {
        Some('{') => self.binary(base.to_int())
        _ => Err(Invalid("binary"))
      }
    _ => Err(Invalid("binary"))
  }
}

///|
fn Lexer::binary(self : Lexer, base : Int) -> Result[@value.Cell, ScanError] {
  self.bump() |> ignore
  let digits : Array[Int] = []
  let mut closed = false
  let mut bad : ScanError? = None
  while !closed && bad is None {
    match self.peek() {
      None => bad = Some(Missing("}"))
      Some('}') => {
        self.bump() |> ignore
        closed = true
      }
      Some(char) if is_space(char) => self.bump() |> ignore
      Some(_) =>
        match self.bump() {
          Some(char) =>
            match digit_value(char) {
              Some(value) if value < base => digits.push(value)
              _ => bad = Some(Invalid("binary"))
            }
          None => bad = Some(Missing("}"))
        }
    }
  }
  match bad {
    Some(error) => return Err(error)
    None => ()
  }
  let width = if base == 2 { 8 } else { 2 }
  if digits.length() % width != 0 {
    Err(Invalid("binary"))
  } else {
    let series = @value.Series::binary()
    let mut i = 0
    while i < digits.length() {
      let mut byte = 0
      for _ in 0..<width {
        byte = byte * base + digits[i]
        i = i + 1
      }
      series.push_byte(byte.to_byte()) |> ignore
    }
    Ok(@value.Seq(series, 0))
  }
}
