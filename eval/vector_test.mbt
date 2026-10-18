///|
test "vector make molds integers, floats, and wrapped bytes" {
  // t-vector.c. A bare integer list is int64!. A count is int32! zeros.
  // uint8! wraps. Float and integer vectors cannot be compared.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "v: make vector! [10 20 30] u: make vector! [uint8! [1 2 256]] f: make vector! [1.0 2] (reduce [(mold make vector! [1 2 3]) = {#(int64! [1 2 3])} (mold u) = {#(uint8! [1 2 0])} (mold f) = {#(float64! [1.0 2.0])} (mold make vector! [int16! [1 -2]]) = {#(int16! [1 -2])} (mold make vector! [float32! [1.5]]) = {#(float32! [1.5])} (mold make vector! [integer! 32 [1 2]]) = {#(int32! [1 2])} (mold make vector! [unsigned integer! 8 [1 255]]) = {#(uint8! [1 255])} (mold make vector! [decimal! 64 [1]]) = {#(float64! [1.0])} (mold make vector! 0) = {#(int32! [])} (mold make vector! 3) = {#(int32! [0 0 0])} (form v) = {10 20 30} (length? v) = 3 (pick v 2) = 20 none? pick v 0 none? pick v 4 v/1 = 10 f/2 = 2.0 (type? v) = vector! v = make vector! [10 20 30] u = make vector! [int16! [1 2 0]] (make vector! [1 2]) <> (make vector! [1]) ((try [make vector! []])/id) = 'bad-make-arg ((try [(make vector! [1.0]) = (make vector! [1])])/id) = 'not-same-type]) = reduce [true true true true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
