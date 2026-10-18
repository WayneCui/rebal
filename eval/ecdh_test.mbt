///|
test "ecdh on secp256r1 agrees and can be reinitialized" {
  // dh-test.r3 "ECDH (secp256r1) keys usage".
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "a: ecdh/init none 'secp256r1 b: ecdh/init none 'secp256r1 pa: ecdh/public a pb: ecdh/public b sa: ecdh/secret a pb sb: ecdh/secret b pa (reduce [mold a ecdh/curve a ecdh/curve b (length? pa) = 65 pa <> pb (sa = sb) (length? sa) = 32 none? ecdh/init none 'secp192r1 none? ecdh/secret a #{00} release a none? ecdh/public a (type? ecdh/init a 'secp256r1) = handle! (length? ecdh/public a) = 65 (type? try [ecdh/public/secret b pb]) = error!]) = reduce [{#(handle! ecdh)} 'secp256r1 'secp256r1 true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
