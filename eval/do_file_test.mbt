///|
test "do of a file runs in its directory and restores the old one" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "make-dir/deep %/tmp/rebal-do-dir/") is @value.Seq(_),
  )
  @eval.write_file("/tmp/rebal-do-dir/lib.reb", "rebal-do-where: what-dir\n")
  @eval.write_file("/tmp/rebal-do-dir/main.reb", "do %./lib.reb\n")
  @eval.write_file("/tmp/rebal-do-dir/bad.reb", "nope\n")
  assert_true(
    @eval.run(
      env, "home: what-dir do %/tmp/rebal-do-dir/main.reb back: what-dir = home change-dir %/tmp/rebal-do-dir/ expect: what-dir change-dir home there: rebal-do-where = expect all [back there]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "home: what-dir err: try [do %/tmp/rebal-do-dir/bad.reb] all [(type? err) = error! what-dir = home]",
    )
    is @value.Logic(true),
  )
  @eval.write_file("/tmp/rebal-do-plain.reb", "rebal-do-plain: what-dir\n")
  assert_true(
    @eval.run(
      env, "home: what-dir change-dir %/tmp do %rebal-do-plain.reb stayed: rebal-do-plain = what-dir change-dir home all [stayed what-dir = home]",
    )
    is @value.Logic(true),
  )
}
