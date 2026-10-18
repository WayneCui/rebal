///|
test "typeset make keeps catalog order and membership" {
  // t-typeset.c. Mold walks datatype ids, so the written order is not kept.
  // find accepts a datatype and returns logic. empty? is tail? of no bits.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "t: make typeset! [object! block! map!] (reduce [(mold t) = {make typeset! [block! map! object!]} (mold make typeset! []) = {make typeset! []} (mold make typeset! [struct! image! integer!]) = {make typeset! [integer! image! struct!]} (mold make typeset! [integer! integer!]) = {make typeset! [integer!]} find t block! find t map! find t object! not find t string! empty? make typeset! [] not empty? t t = make typeset! [map! object! block!] t <> make typeset! [block! map!] (type? t) = typeset! ((try [make typeset! 1])/id) = 'bad-make-arg ((try [make typeset! [foo!]])/id) = 'invalid-arg ((try [find t 1])/id) = 'invalid-arg]) = reduce [true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
