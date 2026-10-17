///|
test "a function rejects an argument of the wrong type" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "f: func [x [integer!]] [x + 1] f 2") is @value.Integer(3L),
  )
  match @eval.run(env, "f: func [x [integer! string!]] [x] f {a}") {
    @value.Seq(text, _) => {
      assert_true(text.datatype() == @value.String)
      assert_true(text.code(0) == Some(97))
    }
    _ => fail("string arg")
  }
  let rejected = try {
    @eval.run(@eval.Env::new(), "f: func [x [integer!]] [x] f {a}") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(rejected)
}
