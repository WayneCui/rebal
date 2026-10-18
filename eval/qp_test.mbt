///|
test "quoted-printable restores utf-8 and drops a soft line break" {
  // codecs-test.r3 "decode Quoted-Printable", plus the soft break and /uri.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(decode 'quoted-printable {Hol=C4=8Di=C4=8Dka}) = {Holčička} (decode 'quoted-printable %Hol=C4=8Di=C4=8Dka) = %Holčička (decode 'quoted-printable #{486F6C3D43343D3844693D43343D38446B61}) = #{486F6CC48D69C48D6B61} (decode 'quoted-printable \"abc=^M^/de\") = {abcde} (decode 'quoted-printable \"=C3=^M^/=A0\") = {à} (decode 'quoted-printable {a_b}) = {a_b} (decode/uri 'quoted-printable {a_b}) = {a b}]) = reduce [true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "quoted-printable encode escapes utf-8 and wraps after 75 bytes" {
  // codecs-test.r3 "encode Quoted-Printable" and the line-length fold.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "s: {} loop 77 [append s {a}] u: {} loop 76 [append u {a}] e: encode 'quoted-printable s (reduce [(encode 'quoted-printable {Holčička}) = {Hol=C4=8Di=C4=8Dka} (encode 'quoted-printable %Holčička) = %Hol=C4=8Di=C4=8Dka (encode 'quoted-printable #{486F6CC48D69C48D6B61}) = #{486F6C3D43343D3844693D43343D38446B61} (encode 'quoted-printable {a=b}) = {a=3Db} (encode 'quoted-printable {a b}) = {a b} (encode/uri 'quoted-printable {a b}) = {a_b} (encode/uri 'quoted-printable {a_b}) = {a=5Fb} (length? e) = 80 (pick e 76) = #\"=\" (decode 'quoted-printable e) = s (length? encode 'quoted-printable u) = 76]) = reduce [true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
