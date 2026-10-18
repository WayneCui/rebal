///|
test "ico directories list width, depth, and bytes" {
  // codec-ico.reb. A zero width is 256. Cursor files use the same layout.
  // The second sample stores the image bytes out of directory order.
  let env = @eval.Env::new()
  @eval.write_binary("/tmp/rebal-one.ico", [
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x02, 0x02, 0x00, 0x00, 0x01, 0x00, 0x20,
    0x00, 0x04, 0x00, 0x00, 0x00, 0x16, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04,
  ])
  @eval.write_binary("/tmp/rebal-bad.ico", [0x00, 0x00, 0x03, 0x00, 0x00, 0x00])
  assert_true(
    @eval.run(
      env, "one: #{0000010001000202000001002000040000001600000001020304} wide: #{00000100010000000000010020000100000016000000AA} swapped: #{0000010002000101000001000800020000002700000002020000010020000100000026000000221111} cur: #{000002000100010100000100010001000000160000007F} (reduce [(decode 'ico one) = [[2 32 #{01020304}]] (decode 'ico wide) = [[256 32 #{AA}]] (decode 'ico swapped) = [[1 8 #{1111}] [2 32 #{22}]] (decode 'ico cur) = [[1 1 #{7F}]] (decode 'ico #{000001000000}) = [] none? decode 'ico #{000003000000} (load %/tmp/rebal-one.ico) = decode 'ico one (load %/tmp/rebal-one.ICO) = decode 'ico one ((try [load %/tmp/rebal-bad.ico])/id) = 'no-codec ((try [save %/tmp/rebal-one.ico #{00}])/id) = 'not-done ((try [encode 'ico [[2 32 #{00}]]])/id) = 'not-done]) = reduce [true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
