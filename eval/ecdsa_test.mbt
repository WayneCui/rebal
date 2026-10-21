///|
test "ecdsa signs with a p256 handle and verifies the public point" {
  // dh-test.r3 "ECDSA (secp256r1) signing". Two signatures differ.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "a: ecdh/init none 'secp256r1 hash: checksum/method {Hello} 'sha256 sig1: ecdsa/sign a hash sig2: ecdsa a hash pub: ecdh/public a (reduce [(type? sig1) = binary! sig1 <> sig2 ecdsa/verify a hash sig1 ecdsa/verify a hash sig2 ecdsa/verify/curve pub hash sig1 'secp256r1 none? ecdsa/verify a hash #{00} (type? decode 'der sig1) = block! none? ecdsa/verify/curve pub hash sig1 'secp192r1 (type? try [ecdsa/sign #{04} hash]) = error!]) = reduce [true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
