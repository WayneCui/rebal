///|
test "compress and decompress store a zip of named files" {
  let env = @eval.Env::new()
  assert_true(
    @eval.run(env, "(pick compress [] 'zip 1) = 80") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(pick compress [] 'zip 2) = 75") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(decompress (compress [] 'zip) 'zip) = []")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decompress (compress [%hi.txt {hi}] 'zip) 'zip) = reduce [%hi.txt reduce [none checksum/method {hi} 'crc32 #{6869}]]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decompress (compress [%a.txt {A} %b.txt {B}] 'zip) 'zip) = reduce [%a.txt reduce [none checksum/method {A} 'crc32 #{41}] %b.txt reduce [none checksum/method {B} 'crc32 #{42}]]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(decompress (compress [%š.txt {á}] 'zip) 'zip) = reduce [%š.txt reduce [none checksum/method {á} 'crc32 #{C3A1}]]",
    )
    is @value.Logic(true),
  )
  let bad = try {
    @eval.run(env, "compress {hi} 'zip") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
  let level = try {
    @eval.run(env, "compress/level [] 'zip 0") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(level)
  let short = try {
    @eval.run(env, "decompress #{00} 'zip") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(short)
}
