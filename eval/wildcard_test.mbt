///|
test "wildcard keeps names that match star and question mark" {
  let env = @eval.Env::new()
  @eval.make_dir("/tmp/rebal-wild")
  @eval.make_dir("/tmp/rebal-wild/sub")
  @eval.run(env, "write %/tmp/rebal-wild/a.txt {a}") |> ignore
  @eval.run(env, "write %/tmp/rebal-wild/ab.txt {b}") |> ignore
  @eval.run(env, "write %/tmp/rebal-wild/b.r3 {c}") |> ignore
  assert_true(
    @eval.run(
      env, "(wildcard %/tmp/rebal-wild {*.txt}) = [%/tmp/rebal-wild/a.txt %/tmp/rebal-wild/ab.txt]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(wildcard %/tmp/rebal-wild {?.txt}) = [%/tmp/rebal-wild/a.txt]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(wildcard %/tmp/rebal-wild {*}) = [%/tmp/rebal-wild/a.txt %/tmp/rebal-wild/ab.txt %/tmp/rebal-wild/b.r3 %/tmp/rebal-wild/sub/]",
    )
    is @value.Logic(true),
  )
  let missing = try {
    @eval.run(env, "wildcard %/tmp/rebal-no-such-wild {*}") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(missing)
}
