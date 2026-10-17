///|
test "split-path separates the directory from the last name" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(split-path %/a/b/c) = [%/a/b/ %c]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(split-path %file.txt) = [%./ %file.txt]")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(split-path %a/b/) = [%a/ %b/]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(split-path %/) = [%/ %\"\"]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(split-path %.) = [%./ %\"\"]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(split-path %..) = [%../ %\"\"]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(split-path %a/..) = [%a/ %../]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(split-path \"a/b\") = [\"a/\" %b]") is @value.Logic(true),
  )
}
