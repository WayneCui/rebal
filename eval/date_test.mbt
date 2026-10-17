///|
test "date scans, molds, converts, and moves by days" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(mold 1-Feb-0003) = {1-Feb-0003}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold 1-2-2000) = {1-Feb-2000}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold 2013-11-08) = {8-Nov-2013}") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold 8-Nov-2013/17:01) = {8-Nov-2013/17:01}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold 1-2-3/4:00+5:00) = {1-Feb-0003/4:00+5:00}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "1-1-2000 = make date! [1 1 2000]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "1-2-3/4:00 = make date! [1 2 3 4:0]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "1-2-3/4:00+5:00 = make date! [1 2 3 4:0 5:0]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "5-1-2000/4:00 = make date! [1-1-2000 100:0]")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "1-1-2000 + 4 = 5-Jan-2000") is @value.Logic(true))
  assert_true(
    @eval.run(env, "29-2-2024 + 1 = 1-Mar-2024") is @value.Logic(true),
  )
  assert_true(@eval.run(env, "2-1-2000 - 1-1-2000 = 1") is @value.Logic(true))
  assert_true(@eval.run(env, "1-1-2000 < 2-1-2000") is @value.Logic(true))
  let bad = try {
    @eval.run(@eval.Env::new(), "29-2-2023") |> ignore
    false
  } catch {
    error => error.id() == "bad-source"
  }
  assert_true(bad)
}
