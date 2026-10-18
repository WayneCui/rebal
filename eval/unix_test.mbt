///|
test "unixtime converts a zoned date to utc seconds" {
  // codecs-test.r3 "unixtime codec". Decode applies the local zone.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(encode 'unixtime 18-Sep-2019/8:52:31+2:00) = 1568789551 (encode/as 'unixtime 18-Sep-2019/8:52:31+2:00 string!) = {5D81D42F} (encode/as 'unixtime 18-Sep-2019/8:52:31+2:00 binary!) = #{5D81D42F} (encode/as 'unixtime 18-Sep-2019/8:52:31+2:00 integer!) = 1568789551 (type? try [encode/as 'unixtime 18-Sep-2019/8:52:31+2:00 url!]) = error! (encode 'unixtime 1-1-2056/1:2:3) = 2713914123 (encode/as 'unixtime 1-1-2056/1:2:3 string!) = {A1C30B0B} (encode 'unixtime decode 'unixtime 1568789551) = 1568789551 (encode 'unixtime decode 'unixtime {5D81D42F}) = 1568789551 (encode 'unixtime decode 'unixtime #{5D81D42F}) = 1568789551 (encode 'unixtime decode 'unixtime 2713914123) = 2713914123 (encode 'unixtime decode 'unixtime {A1C30B0B}) = 2713914123]) = reduce [true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
