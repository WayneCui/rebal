///|
test "braille shifts characters into the Braille block and back" {
  // codec-braille.reb. Codes below 255 move by 10240.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "b: encode 'braille \"A\" (reduce [b = \"^(2841)\" (decode 'braille b) = \"A\" (decode 'braille encode 'braille \"Hello\") = \"Hello\" (decode 'braille #{41}) = \"A\"]) = reduce [true true true true]",
    )
    is @value.Logic(true),
  )
}
