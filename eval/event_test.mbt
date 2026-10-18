///|
test "event make stores type, offset, and key code" {
  // t-event.c. A bare key becomes type key. A custom event keeps the code
  // but does not expose the key. Offset must fit in a signed 16-bit pair.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "e: make event! [type: 'connect] e2: make e [offset: 0x0] key: make event! [type: 'key key: #\"A\"] bare: make event! [key: #\"B\"] custom: make event! [type: 'custom key: #\"C\"] up: make event! [type: 'key-up key: #\"C\"] coded: make event! [type: 'custom code: 1] (reduce [(type? e) = event! e/type = 'connect e2/type = 'connect e2/offset = 0x0 key/key == #\"A\" none? key/offset key/code = 65 bare/key == #\"B\" bare/type = 'key none? custom/key custom/type = 'custom custom/code = 67 up/key == #\"C\" up/type = 'key-up up/code = 67 coded/type = 'custom coded/code = 1 (make event! [offset: 1x2])/offset = 1x2 (make event! [offset: 32767x-32767])/offset = 32767x-32767 ((try [make event! [offset: 32768x0]])/id) = 'out-of-range ((try [make event! [offset: -32768x0]])/id) = 'out-of-range ((try [make event! 1])/id) = 'expect-val ((try [make event! [type: 'nope]])/id) = 'invalid-arg ((try [make event! [foo: 1]])/id) = 'bad-field-set]) = reduce [true true true true true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
