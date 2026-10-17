///|
test "now returns the local date and its parts" {
  let env = @eval.Env::new()
  match @eval.run(env, "now") {
    @value.Date(date) => {
      assert_true(date.time() is Some(_))
      assert_true(date.zone() is Some(_))
      let year = date.year().to_int64()
      let month = date.month().to_int64()
      let day = date.day().to_int64()
      assert_same(@eval.run(env, "now/year"), year)
      assert_same(@eval.run(env, "now/month"), month)
      assert_same(@eval.run(env, "now/day"), day)
      let ordinal = year_day(date.year(), date.month(), date.day()).to_int64()
      assert_same(@eval.run(env, "now/yearday"), ordinal)
      let weekday = week_day(date.year(), date.month(), date.day()).to_int64()
      assert_same(@eval.run(env, "now/weekday"), weekday)
    }
    _ => fail("date")
  }
  match @eval.run(env, "now/date") {
    @value.Date(date) => {
      assert_true(date.time() is None)
      assert_true(date.zone() is None)
    }
    _ => fail("date only")
  }
  match (@eval.run(env, "now"), @eval.run(env, "now/time")) {
    (@value.Date(date), @value.Time(seconds)) =>
      match date.time() {
        Some(stored) => assert_true((seconds - stored).abs() < 2.0)
        None => fail("time")
      }
    _ => fail("time")
  }
  match (@eval.run(env, "now"), @eval.run(env, "now/zone")) {
    (@value.Date(date), @value.Time(seconds)) =>
      match date.zone() {
        Some(minutes) => assert_true(seconds == minutes.to_double() * 60.0)
        None => fail("zone")
      }
    _ => fail("zone")
  }
  match @eval.run(env, "now/utc") {
    @value.Date(date) =>
      match date.zone() {
        Some(minutes) => assert_true(minutes == 0)
        None => fail("utc")
      }
    _ => fail("utc")
  }
  let both = try {
    @eval.run(env, "now/year/month") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(both)
}

///|
fn assert_same(cell : @value.Cell, expected : Int64) -> Unit raise {
  match cell {
    @value.Integer(found) => assert_true(found == expected)
    _ => fail("integer")
  }
}

///|
fn year_day(year : Int, month : Int, day : Int) -> Int {
  let lengths = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  let mut total = day
  let mut cursor = 1
  while cursor < month {
    total = total + lengths[cursor]
    cursor = cursor + 1
  }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  if leap && month > 2 {
    total + 1
  } else {
    total
  }
}

///|
/// Monday is 1 and Sunday is 7.
fn week_day(year : Int, month : Int, day : Int) -> Int {
  let shift = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let adjusted = if month < 3 { year - 1 } else { year }
  let sunday = (
      adjusted +
      adjusted / 4 -
      adjusted / 100 +
      adjusted / 400 +
      shift[month - 1] +
      day
    ) %
    7
  if sunday == 0 {
    7
  } else {
    sunday
  }
}
