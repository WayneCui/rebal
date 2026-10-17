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
    @eval.run(env, "compress {a} 'br") |> ignore
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

///|
test "compress and decompress round-trip gzip" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(pick compress {abc} 'gzip 1) = 31") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(pick compress {abc} 'gzip 2) = 139") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decompress compress {abc} 'gzip 'gzip) = #{616263}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decompress compress {} 'gzip 'gzip) = #{}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decompress compress {test test test} 'gzip 'gzip) = #{7465737420746573742074657374}",
    )
    is @value.Logic(true),
  )
}

///|
test "compress/level 0 stores the bytes without shrinking them" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(compress/level {} 'zlib 0) = #{7801010000FFFF00000001}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(compress/level {test test test} 'zlib 0) = #{7801010E00F1FF746573742074657374207465737429390581}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(compress/level {} 'deflate 0) = #{010000FFFF}")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(compress/level {test test test} 'deflate 0) = #{010E00F1FF7465737420746573742074657374}",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(skip compress/level {} 'gzip 0 10) = #{010000FFFF0000000000000000}",
    )
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "compress/level {a} 'zlib 10") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}
