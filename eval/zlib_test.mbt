///|
test "compress and decompress round-trip zlib" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(decompress compress {abc} 'zlib 'zlib) = #{616263}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decompress compress {} 'zlib 'zlib) = #{}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decompress compress {test test test} 'zlib 'zlib) = #{7465737420746573742074657374}",
    )
    is @value.Logic(true),
  )
  let other = try {
    @eval.run(env, "compress {a} 'gzip") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(other)
  let bad = try {
    @eval.run(env, "decompress #{00} 'zlib") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}

///|
test "compress and decompress round-trip raw deflate" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(decompress compress {abc} 'deflate 'deflate) = #{616263}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decompress compress {} 'deflate 'deflate) = #{}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decompress compress {test test test} 'deflate 'deflate) = #{7465737420746573742074657374}",
    )
    is @value.Logic(true),
  )
}
