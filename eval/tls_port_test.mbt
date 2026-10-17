///|
test "tls port handshakes, then writes and reads plaintext" {
  let env = @eval.Env::new()
  @eval.set_tls_verify(false)
  let number = @eval.tls_serve()
  assert_true(number > 0)
  let source = "p: open tls://127.0.0.1:" +
    number.to_string() +
    " q: query p write p \"hi^/\" got: read p close p (q/type = 'tls) and (got = \"hi^/\")"
  assert_true(@eval.run(env, source) is @value.Logic(true))
  @eval.set_tls_verify(true)
  let checked = @eval.tls_serve()
  assert_true(checked > 0)
  let refused = try {
    @eval.run(env, "open tls://127.0.0.1:" + checked.to_string()) |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(refused)
}
