///|
test "make a map, select a key, and set it through a path" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(select make map! [a 1 b 2] 'b) = 2") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(select make map! [a 1] 'c) = none") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(length? make map! [a 1 b 2]) = 2") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(mold make map! [a 1]) = {make map! [a 1]}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "m: make map! [a 1] (m/a) = 1") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "m: make map! [a 1] m/a: 3 (select m 'a) = 3")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "m: make map! [] m/b: 4 (select m 'b) = 4")
    is @value.Logic(true),
  )
  let odd = try {
    @eval.run(env, "make map! [a]") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(odd)
}

///|
test "mold/all of a map loads back as the same map" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "inner: make map! [text: \"ok\"] m: make map! reduce ['type 'user-message 'payload inner 'index 0] back: load mold/all m (reduce [(mold/all m) = {#(map! [type: user-message payload: #(map! [text: \"ok\"]) index: 0])} (select back 'type) = 'user-message (select select back 'payload 'text) = \"ok\" (select back 'index) = 0]) = reduce [true true true true]",
    )
    is @value.Logic(true),
  )
}
