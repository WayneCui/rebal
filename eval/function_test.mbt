///|
test "function keeps body set-words local" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "f: function [x] [n: x + 1 n] (f 2) = 3")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "n: 9 f: function [x] [n: x] f 4 n = 9")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "g: function [n] [n: n + 1 n] (g 2) = 3")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "h: funct [x] [either x [a: 1] [a: 2] a] (h true) = 1")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(h false) = 2") is @value.Logic(true))
}
