///|
test "cause-error raises an error try can catch" {
  let env = @eval.Env::new()
  match @eval.run(env, "try [cause-error 'script 'too-small 3]") {
    @value.Error(error) => {
      assert_true(error.id == "too-small")
      assert_true(error.arg1 == "3")
    }
    _ => fail("error")
  }
  match @eval.run(env, "try [cause-error 'user 'bad [10 20]]") {
    @value.Error(error) => assert_true(error.id == "bad" && error.arg1 == "10")
    _ => fail("error")
  }
  let raised = try {
    @eval.run(env, "cause-error 'script 'too-small 3") |> ignore
    false
  } catch {
    error => error.id() == "too-small"
  }
  assert_true(raised)
  let bad = try {
    @eval.run(env, "cause-error 1 'bad 0") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
