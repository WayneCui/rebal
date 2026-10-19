///|
test "a path reads an error id and its first argument" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "e: try [encoding? \"ab\"] c: try [cause-error 'script 'too-small 3] (reduce [e/id = 'expect-arg e/arg1 = \"encoding?\" c/id = 'too-small c/arg1 = \"3\" (type? try [e/type]) = error!]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "an action failure names the operation" {
  let env = @eval.Env::new()
  match @eval.run(env, "try [append 1 2]") {
    @value.Error(error) => {
      assert_true(error.id == "cannot")
      assert_true(error.arg1 == "append")
    }
    _ => fail("append")
  }
}

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
