///|
test "tcp port connects, writes a line, and reads the echo" {
  let env = @eval.Env::new()
  let number = @eval.tcp_echo()
  assert_true(number > 0)
  let source = "p: open tcp://127.0.0.1:" +
    number.to_string() +
    " q: query p write p \"hi^/\" got: read p close p (q/type = 'tcp) and (got = \"hi^/\")"
  assert_true(@eval.run(env, source) is @value.Logic(true))
  let refused = try {
    @eval.run(env, "open tcp://127.0.0.1:1") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(refused)
}
