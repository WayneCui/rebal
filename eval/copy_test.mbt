///|
test "copy and copy/deep clone series and maps" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "b: [1 [2 3]] c: copy b d: copy/deep b append c/2 4 (reduce [b/2 = [2 3 4] d/2 = [2 3] not same? b d]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "s: \"ab\" t: copy/deep s (reduce [t = \"ab\" not same? s t]) = reduce [true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "m: make map! [a: 1] n: copy/deep m n/a: 2 (reduce [m/a = 1 n/a = 2 not same? m n]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "name: \"s1.events.reb\" (reduce [(copy/part name (length? name) - length? \".events.reb\") = \"s1\" (copy/part \"abcd\" 2) = \"ab\" (copy/part \"abcd\" 0) = \"\" (copy/part [1 2 3] 2) = [1 2] (copy/part/deep [1 [2]] 1) = [1]]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "copy/part [1 2]") |> ignore
    false
  } catch {
    error => error.id() == "missing-arg"
  }
  assert_true(bad)
}
