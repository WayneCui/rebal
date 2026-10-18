///|
test "struct make stores field widths and zero values" {
  // t-struct.c. length? is the byte size. float! molds as float32!.
  // A dimension above 1 is a vector on access and a block in the mold.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "s: make struct! [a [int8!]] t: make struct! [a [int8!] b [int16!]] u: make struct! [a [int8! [2]]] w: make struct! [a [word!]] f: make struct! [a [float!] b [double!]] z: make struct! [a [int8! [0]]] one: make struct! [A [int8! [1]]] (reduce [(mold s) = {#(struct! [a [int8!]] [a: 0])} (length? s) = 1 s/a = 0 (mold t) = {#(struct! [a [int8!] b [int16!]] [a: 0 b: 0])} (length? t) = 3 t/a = 0 t/b = 0 (mold u) = {#(struct! [a [int8! [2]]] [a: [0 0]])} (length? u) = 2 (mold u/a) = {#(int8! [0 0])} (type? u/a) = vector! (mold w) = {#(struct! [a [word!]] [a: _])} none? w/a (mold f) = {#(struct! [a [float32!] b [float64!]] [a: 0.0 b: 0.0])} f/a = 0.0 f/b = 0.0 (mold z) = {#(struct! [a [int8! [0]]] [a: 0])} (length? z) = 0 (mold z/a) = {#(int8! [])} (mold one) = {#(struct! [A [int8! [1]]] [A: 0])} one/a = 0 (length? one) = 1 s = make struct! [a [int8!]] (type? s) = struct! (length? make struct! [a [word! [2]]]) = 8 (mold make struct! [a [word! [2]]]) = {#(struct! [a [word! [2]]] [a: [_ _]])} none? pick (make struct! [a [word! [2]]])/a 1 ((try [make struct! []])/id) = 'malconstruct ((try [make struct! 1])/id) = 'bad-make-arg ((try [make struct! [a [integer!]]])/id) = 'invalid-arg ((try [make struct! [a]])/id) = 'malconstruct]) = reduce [true true true true true true true true true true true true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
