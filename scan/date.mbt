///|
priv enum DateTry {
  Skip
  Fail
  Ready(@value.Cell)
}

///|
fn is_letter(char : Char) -> Bool {
  (char >= 'A' && char <= 'Z') || (char >= 'a' && char <= 'z')
}

///|
fn fold_letter(char : Char) -> Char {
  if char >= 'A' && char <= 'Z' {
    (char.to_int() + 32).to_char().unwrap()
  } else {
    char
  }
}

///|
/// `1-2-2000` and `2013-11-08` and `8-Nov-2013/17:01+1:00`.
fn Lexer::date_try(self : Lexer, first : Array[Int]) -> DateTry {
  match signed(first, 10, 1L) {
    None => Skip
    Some(leading) => {
      self.bump() |> ignore
      match self.date_month() {
        None => Skip
        Some(month) =>
          match self.peek() {
            Some('-') => {
              self.bump() |> ignore
              let tail = self.digits(10)
              match signed(tail, 10, 1L) {
                None => Skip
                Some(following) =>
                  self.finish_date(
                    first.length() >= 4,
                    leading,
                    month,
                    following,
                  )
              }
            }
            _ => Skip
          }
      }
    }
  }
}

///|
fn Lexer::date_month(self : Lexer) -> Int? {
  match self.peek() {
    Some(char) if is_digit(char) =>
      match signed(self.digits(10), 10, 1L) {
        Some(month) if month >= 1L && month <= 12L => Some(month.to_int())
        _ => None
      }
    Some(char) if is_letter(char) => {
      let letters : Array[Char] = []
      let mut reading = true
      while reading {
        match self.peek() {
          Some(next) if is_letter(next) => {
            self.bump() |> ignore
            letters.push(fold_letter(next))
          }
          _ => reading = false
        }
      }
      if letters.length() < 3 {
        None
      } else {
        month_number(letters[0], letters[1], letters[2])
      }
    }
    _ => None
  }
}

///|
fn month_number(a : Char, b : Char, c : Char) -> Int? {
  if a == 'j' && b == 'a' && c == 'n' {
    Some(1)
  } else if a == 'f' && b == 'e' && c == 'b' {
    Some(2)
  } else if a == 'm' && b == 'a' && c == 'r' {
    Some(3)
  } else if a == 'a' && b == 'p' && c == 'r' {
    Some(4)
  } else if a == 'm' && b == 'a' && c == 'y' {
    Some(5)
  } else if a == 'j' && b == 'u' && c == 'n' {
    Some(6)
  } else if a == 'j' && b == 'u' && c == 'l' {
    Some(7)
  } else if a == 'a' && b == 'u' && c == 'g' {
    Some(8)
  } else if a == 's' && b == 'e' && c == 'p' {
    Some(9)
  } else if a == 'o' && b == 'c' && c == 't' {
    Some(10)
  } else if a == 'n' && b == 'o' && c == 'v' {
    Some(11)
  } else if a == 'd' && b == 'e' && c == 'c' {
    Some(12)
  } else {
    None
  }
}

///|
fn Lexer::finish_date(
  self : Lexer,
  year_first : Bool,
  leading : Int64,
  month : Int,
  following : Int64,
) -> DateTry {
  let year = if year_first { leading.to_int() } else { following.to_int() }
  let day = if year_first { following.to_int() } else { leading.to_int() }
  if !@value.valid_date(year, month, day) {
    Fail
  } else {
    match self.date_clock() {
      Fail => Fail
      Skip =>
        Ready(@value.Date(@value.DateValue::make(year, month, day, None, None)))
      Ready(cell) =>
        match cell {
          @value.Time(seconds) =>
            match self.date_zone() {
              Fail => Fail
              Skip =>
                Ready(
                  @value.Date(
                    @value.DateValue::make(
                      year,
                      month,
                      day,
                      Some(seconds),
                      None,
                    ),
                  ),
                )
              Ready(zone) =>
                match zone {
                  @value.Integer(minutes) =>
                    Ready(
                      @value.Date(
                        @value.DateValue::make(
                          year,
                          month,
                          day,
                          Some(seconds),
                          Some(minutes.to_int()),
                        ),
                      ),
                    )
                  _ => Fail
                }
            }
          _ => Fail
        }
    }
  }
}

///|
fn Lexer::date_clock(self : Lexer) -> DateTry {
  match self.peek() {
    Some('/') | Some('T') => {
      self.bump() |> ignore
      match self.number() {
        Ok(@value.Time(seconds)) if seconds >= 0.0 && seconds < 86400.0 =>
          Ready(@value.Time(seconds))
        _ => Fail
      }
    }
    _ => Skip
  }
}

///|
fn Lexer::date_zone(self : Lexer) -> DateTry {
  match self.peek() {
    Some('+') | Some('-') => {
      let negative = self.peek() is Some('-')
      self.bump() |> ignore
      match self.number() {
        Ok(@value.Time(seconds)) if seconds >= 0.0 => {
          let minutes = (seconds / 60.0).to_int()
          let zone = if negative { 0 - minutes } else { minutes }
          Ready(@value.Integer(zone.to_int64()))
        }
        _ => Fail
      }
    }
    _ => Skip
  }
}
