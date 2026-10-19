///|
test "compose evaluates parens and splices blocks" {
  let env = @eval.Env::new()
  match @eval.run(env, "compose [1 (1 + 1) 3]") {
    @value.Seq(block, _) => {
      assert_true(block.item(0).unwrap() is @value.Integer(1L))
      assert_true(block.item(1).unwrap() is @value.Integer(2L))
      assert_true(block.item(2).unwrap() is @value.Integer(3L))
    }
    _ => fail("compose")
  }
  match @eval.run(env, "compose [a ([1 2])]") {
    @value.Seq(block, _) => assert_eq(block.length(), 3)
    _ => fail("splice")
  }
  assert_true(
    @eval.run(env, "(compose/only [a ([1 2])]) = [a [1 2]]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(compose [a [(1 + 1)]]) = [a [(1 + 1)]]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(compose/deep [a [(1 + 1)]]) = [a [2]]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(compose/deep/only [a [([1 2])]]) = [a [[1 2]]]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "f: func [] [7] (mold compose/deep [list-ref: (none) idx: (1) dispose: (f)]) = \"[list-ref: none idx: 1 dispose: 7]\"",
    )
    is @value.Logic(true),
  )
}
