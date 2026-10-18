///|
test "SAFE encrypts with aes-192-gcm and the header vector" {
  // codec-safe.reb. The key is the first 24 bytes of SHA-256 of the password.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "bin: encode/key 'safe #{6869} \"secret\" blk: encode/key 'safe [1 2] \"secret\" (reduce [bin = #{5341464520312E300000000000028F434346648F6B96DF89DDA901C5176B10A6D83961DD3C1AC88B59B2DC327AA40B6165732D3139322D67636D00000002701C} (decode/password 'safe bin \"secret\") = #{6869} (decode/password 'safe blk \"secret\") = [1 2] (decode/password 'safe encode/key 'safe #{} \"secret\" \"secret\") = #{} none? decode/password 'safe bin \"nope\" none? decode/password 'safe #{00} \"secret\"]) = reduce [true true true true true true]",
    )
    is @value.Logic(true),
  )
}
