///|
pub struct DateValue {
  year : Int
  month : Int
  day : Int
  time : Double?
  zone : Int?
}

///|
pub fn DateValue::make(
  year : Int,
  month : Int,
  day : Int,
  time : Double?,
  zone : Int?,
) -> DateValue {
  { year, month, day, time, zone, }
}

///|
pub fn DateValue::year(self : DateValue) -> Int {
  self.year
}

///|
pub fn DateValue::month(self : DateValue) -> Int {
  self.month
}

///|
pub fn DateValue::day(self : DateValue) -> Int {
  self.day
}

///|
pub fn DateValue::time(self : DateValue) -> Double? {
  self.time
}

///|
pub fn DateValue::zone(self : DateValue) -> Int? {
  self.zone
}

///|
pub fn DateValue::same(self : DateValue, other : DateValue) -> Bool {
  self.year == other.year &&
  self.month == other.month &&
  self.day == other.day &&
  self.time == other.time &&
  self.zone == other.zone
}

///|
pub fn DateValue::order(self : DateValue, other : DateValue) -> Int {
  if self.year != other.year {
    if self.year < other.year {
      -1
    } else {
      1
    }
  } else if self.month != other.month {
    if self.month < other.month {
      -1
    } else {
      1
    }
  } else if self.day != other.day {
    if self.day < other.day {
      -1
    } else {
      1
    }
  } else {
    let left = match self.time {
      Some(n) => n
      None => 0.0
    }
    let right = match other.time {
      Some(n) => n
      None => 0.0
    }
    if left < right {
      -1
    } else if left > right {
      1
    } else {
      let left_zone = match self.zone {
        Some(n) => n
        None => 0
      }
      let right_zone = match other.zone {
        Some(n) => n
        None => 0
      }
      if left_zone < right_zone {
        -1
      } else if left_zone > right_zone {
        1
      } else {
        0
      }
    }
  }
}

///|
pub fn DateValue::shift(self : DateValue, days : Int) -> DateValue {
  let moved = shift_ymd(self.year, self.month, self.day, days)
  DateValue::make(moved.0, moved.1, moved.2, self.time, self.zone)
}

///|
pub fn DateValue::add_seconds(self : DateValue, extra : Double) -> DateValue {
  let base = match self.time {
    Some(n) => n
    None => 0.0
  }
  let total = base + extra
  let mut days = (total / 86400.0).to_int()
  let mut rest = total - days.to_double() * 86400.0
  if rest < 0.0 {
    rest = rest + 86400.0
    days = days - 1
  }
  let moved = shift_ymd(self.year, self.month, self.day, days)
  DateValue::make(
    moved.0,
    moved.1,
    moved.2,
    Some(snap_seconds(rest)),
    self.zone,
  )
}

///|
pub fn DateValue::day_diff(self : DateValue, earlier : DateValue) -> Int {
  days_from_civil(self.year, self.month, self.day) -
  days_from_civil(earlier.year, earlier.month, earlier.day)
}

///|
pub fn valid_date(year : Int, month : Int, day : Int) -> Bool {
  if month < 1 || month > 12 || day < 1 {
    false
  } else {
    day <= month_length(year, month)
  }
}

///|
fn month_length(year : Int, month : Int) -> Int {
  if month == 2 {
    if leap_year(year) {
      29
    } else {
      28
    }
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else {
    31
  }
}

///|
fn leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    true
  } else if year % 100 == 0 {
    false
  } else {
    year % 4 == 0
  }
}

///|
fn shift_ymd(year : Int, month : Int, day : Int, days : Int) -> (Int, Int, Int) {
  civil_from_days(days_from_civil(year, month, day) + days)
}

///|
/// Days since 1970-01-01. Howard Hinnant's civil calendar conversion.
fn days_from_civil(year : Int, month : Int, day : Int) -> Int {
  let (y, m) = if month <= 2 {
    (year - 1, month + 9)
  } else {
    (year, month - 3)
  }
  let era = if y >= 0 { y / 400 } else { (y - 399) / 400 }
  let yoe = y - era * 400
  let doy = (153 * m + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
fn civil_from_days(days : Int) -> (Int, Int, Int) {
  let z = days + 719468
  let era = if z >= 0 { z / 146097 } else { (z - 146096) / 146097 }
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let mut y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  if m <= 2 {
    y = y + 1
  }
  (y, m, d)
}
