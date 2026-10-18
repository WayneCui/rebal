///|
test "rc4 key and stream round trip and match rfc 6229" {
  // rc4-test.r3 "Basic RC4 usage" and the first RFC 6229 key.
  // The 16 bytes at offset 240 are the third window in that file.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "a: rc4/key #{CAFE} b: rc4/key #{CAFE} held: #{48656C6C6F} msg: copy held cipher: rc4/stream a msg secret: copy cipher plain: rc4/stream b cipher again: rc4/stream a copy held k: rc4/key #{0102030405} first: rc4/stream k #{0000000000000000000000000000000000000000000000000000000000000000} second: rc4/stream k #{00000000000000000000000000000000} k2: rc4/key #{0102030405} z: #{} loop 256 [append z #{00}] window: at rc4/stream k2 z 241 (reduce [mold a query a 'type secret <> held plain again <> secret first second window none? rc4/key #{} release k (type? try [rc4/stream k #{}])]) = reduce [{#(handle! rc4)} 'rc4 true held true #{B2396305F03DC027CCC3524A0A1118A86982944F18FC82D589C403A47A0D0919} #{B68F78C28D15D822234C6CB8C5F6C4AC} #{28CB1132C96CE286421DCAADB8B69EAE} true true error!]",
    )
    is @value.Logic(true),
  )
}
