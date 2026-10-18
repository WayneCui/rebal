///|
test "srt cues round-trip as start, end, and text" {
  // codec-srt.reb. A comma in a timestamp is a decimal point.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "cue: [0:0:1.5 0:0:3 \"Hello^/there\"] (reduce [(encode 'srt cue) = \"1^/0:00:01.5 --> 0:00:03^/Hello^/there^/^/\" (decode 'srt encode 'srt cue) = cue (decode 'srt \"1^/00:00:01,500 --> 00:00:03,000^/Hi^/^/\") = [0:00:01.5 0:00:03 \"Hi\"] none? decode 'srt \"nope\"]) = reduce [true true true true]",
    )
    is @value.Logic(true),
  )
}
