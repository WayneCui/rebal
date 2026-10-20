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

///|
test "tcp listen accepts and awake echoes bytes" {
  let env = @eval.Env::new()
  ignore(
    @eval.run(
      env,
      "s: open tcp://:0 " +
      "s/awake: func [e /local c] [" +
      "  if e/type = 'accept [" +
      "    c: first e/port " +
      "    c/awake: func [e] [" +
      "      switch e/type [" +
      "        read [write e/port e/port/data]" +
      "        wrote [close e/port return true]" +
      "        close [return true]" +
      "      ]" +
      "      false" +
      "    ]" +
      "    read c" +
      "  ]" +
      "  false" +
      "]",
    ),
  )
  let number = match @eval.run(env, "s/spec/port") {
    @value.Integer(n) => n.to_int()
    _ => 0
  }
  assert_true(number > 0)
  assert_eq(@eval.tcp_probe(number, "hi"), 0)
  assert_true(@eval.run(env, "wait [s 2]") is @value.None)
  ignore(@eval.run(env, "close s"))
  // Client thread may still be finishing recv after the server closes.
  let mut code = @eval.tcp_probe_code()
  let mut spins = 0
  while code != 0 && spins < 50 {
    ignore(@eval.run(env, "wait 0.02"))
    code = @eval.tcp_probe_code()
    spins = spins + 1
  }
  assert_eq(code, 0)
  assert_eq(@eval.tcp_probe_result(), "hi")
}
