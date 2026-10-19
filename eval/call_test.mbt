///|
test "call waits for an exit code and captures output" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(call/wait [%/usr/bin/true]) = 0") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(call/wait [%/usr/bin/false]) = 1") is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "buf: \"\" call/wait/output [%/bin/echo hi] buf buf = \"hi^/\"",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "buf: \"\" call/shell/wait/output {echo hi} buf buf = \"hi^/\"",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "out: \"\" err: \"\" code: call/wait/shell/output/error {echo hi; echo bad 1>&2; exit 3} out err (reduce [code = 3 out = \"hi^/\" err = \"bad^/\"]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "pid: call %/usr/bin/true (type? pid) = integer! pid > 0")
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "call/info {x}") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
