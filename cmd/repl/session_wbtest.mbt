///|
test "a session keeps the same frame across lines" {
  let env = @eval.Env::new()
  let (set, pending) = take_line(env, "", "x: 1 + 2")
  assert_eq(set, "3")
  assert_eq(pending, "")
  let (got, still) = take_line(env, pending, "x")
  assert_eq(got, "3")
  assert_eq(still, "")
  let (open, waiting) = take_line(env, "", "[")
  assert_eq(open, "")
  assert_eq(waiting, "[")
  assert_eq(prompt_text(waiting), ".. ")
  let (closed, done) = take_line(env, waiting, "1]")
  assert_eq(closed, "[1]")
  assert_eq(done, "")
  assert_eq(prompt_text(done), ">> ")
  let (skipped, empty) = take_line(env, "", "")
  assert_eq(skipped, "")
  assert_eq(empty, "")
  let (bad, cleared) = take_line(env, "", "2#12")
  assert_eq(bad, "make error! [id: bad-source arg1: \"invalid\"]")
  assert_eq(cleared, "")
  let leftover = finish(env, "[")
  assert_eq(leftover, "make error! [id: bad-source arg1: \"missing\"]")
  let quit = try {
    take_line(env, "", "quit") |> ignore
    false
  } catch {
    @eval.Quit => true
    _ => false
  }
  assert_true(quit)
  let q = try {
    take_line(env, "", "q") |> ignore
    false
  } catch {
    @eval.Quit => true
    _ => false
  }
  assert_true(q)
  let caught = try {
    take_line(env, "", "try [q]") |> ignore
    false
  } catch {
    @eval.Quit => true
    _ => false
  }
  assert_true(caught)
}

///|
test "quit stops the host without printing an error" {
  let env = @eval.Env::new()
  assert_true(line_reply(env, "", "quit") is Halt)
  assert_true(line_reply(env, "", "q") is Halt)
  assert_true(line_reply(env, "", "try [q]") is Halt)
  assert_true(finish_reply(env, "quit") is Halt)
  assert_true(finish_reply(env, "q") is Halt)
  assert_eq(once_reply("quit"), None)
  assert_eq(once_reply("q"), None)
  match line_reply(env, "", "1 + 1") {
    Keep(text, rest) => {
      assert_eq(text, "2")
      assert_eq(rest, "")
    }
    Halt => assert_true(false)
  }
  match line_reply(env, "", "2#12") {
    Keep(text, rest) => {
      assert_eq(text, "make error! [id: bad-source arg1: \"invalid\"]")
      assert_eq(rest, "")
    }
    Halt => assert_true(false)
  }
  match once_reply("1 + 1") {
    Some(text) => assert_eq(text, "2")
    None => assert_true(false)
  }
  match once_reply("2#12") {
    Some(text) =>
      assert_eq(text, "make error! [id: bad-source arg1: \"invalid\"]")
    None => assert_true(false)
  }
}
