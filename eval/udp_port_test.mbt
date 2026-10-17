///|
test "udp port sends one datagram and reads the echo" {
  let env = @eval.Env::new()
  let number = @eval.udp_echo()
  assert_true(number > 0)
  let source = "p: open udp://127.0.0.1:" +
    number.to_string() +
    " q: query p write p {hi} got: read p close p (q/type = 'udp) and (got = {hi})"
  assert_true(@eval.run(env, source) is @value.Logic(true))
}
