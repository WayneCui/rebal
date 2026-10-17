///|
test "load of a pem file returns the PKIX block" {
  // crypt-test.r3 "Load PKIX data from file". %.ssh uses the same codec.
  let env = @eval.Env::new()
  @eval.write_file(
    "/tmp/rebal-dh.pem", "-----BEGIN DH PARAMETERS-----\nMIIBCAKCAQEAhR9gLa+RbIUY+u3qZHRwTfw4Q0VoJOv4FK3et9HQNSvZmmUqzcG/\nt3v3TPD3NRsLTh7hrvQcWFR7dsgqLFjqrMvthcRXsLYOxsT9ERL3nMPloEItggRG\n9hk3RzGFYb9nx56RXDJ3Nh+/pYfG3Ab+3gt+V/7Ato+Ws61lHVQmQ1cBUvkdjy4i\nuIm5vr91VVgMc8Bi9PvhsPhjU4f9LQIykiY7+nsJpbgNdlU55Db8/Atc3PnL11z/\nxXjmnj1QBjWymkz5LDEMJYCkMcFGwiToL6+jYjAkG1GpU6Jt4C5Z00E4LERy/jCi\ngeGoH8yNQvldeqw5lTcNpaWWB2+ROqUj0wIBAg==\n-----END DH PARAMETERS-----",
  )
  assert_true(
    @eval.run(
      env, "pkix: load %/tmp/rebal-dh.pem\n(reduce [pkix/label type? pkix/binary]) = reduce [{DH PARAMETERS} binary!]",
    )
    is @value.Logic(true),
  )
  @eval.write_file(
    "/tmp/rebal-key.ssh", "---- BEGIN SSH2 PUBLIC KEY ----\nAAAA\n---- END SSH2 PUBLIC KEY ----\n",
  )
  assert_true(
    @eval.run(
      env, "key: load %/tmp/rebal-key.ssh\n(reduce [key/label key/binary]) = reduce [{SSH2 PUBLIC KEY} #{000000}]",
    )
    is @value.Logic(true),
  )
  @eval.write_file("/tmp/rebal-bad.pem", "not armor\n")
  assert_true(
    @eval.run(env, "none? load %/tmp/rebal-bad.pem") is @value.Logic(true),
  )
}
