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
