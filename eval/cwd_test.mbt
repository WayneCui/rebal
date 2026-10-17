///|
test "what-dir is an absolute file and change-dir returns there" {
  let env = @eval.Env::new()
  @eval.make_dir("/tmp/rebal-cwd")
  assert_true(@eval.run(env, "(type? what-dir) = file!") is @value.Logic(true))
  assert_true(@eval.run(env, "(first what-dir) = #\"/\"") is @value.Logic(true))
  assert_true(@eval.run(env, "(last what-dir) = #\"/\"") is @value.Logic(true))
  assert_true(
    @eval.run(
      env, "old: what-dir moved: change-dir %/tmp/rebal-cwd home: change-dir old all [(pick split-path undirize moved 2) = %rebal-cwd (last moved) = #\"/\" home = old (what-dir) = old]",
    )
    is @value.Logic(true),
  )
  let missing = try {
    @eval.run(env, "change-dir %/tmp/rebal-no-such-cwd/") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(missing)
  let file = try {
    @eval.run(
      env, "write %/tmp/rebal-not-dir.txt {x} change-dir %/tmp/rebal-not-dir.txt",
    )
    |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(file)
}
