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

///|
test "preset typesets cover numbers, series, and words" {
  // Init_Typesets. number! is integer, decimal, and percent. series! does not
  // include bitset! or map!. A typeset word inside make is merged.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(mold number!) = {make typeset! [integer! decimal! percent!]} (mold scalar!) = {make typeset! [integer! decimal! percent! money! char! pair! tuple! time! date!]} (mold any-word!) = {make typeset! [word! set-word! get-word! lit-word! refinement! issue!]} (mold any-path!) = {make typeset! [path! set-path!]} (mold any-function!) = {make typeset! [op! closure! function!]} (mold any-string!) = {make typeset! [string! file! email! url! tag!]} (mold any-block!) = {make typeset! [block! paren! path! set-path!]} (mold series!) = {make typeset! [binary! string! file! email! url! tag! image! vector! block! paren! path! set-path!]} (mold any-object!) = {make typeset! [object! module! error! port!]} find number! integer! not find number! money! find series! block! not find series! bitset! not find series! map! find any-string! url! find any-block! path! not find any-block! map! find any-function! op! find any-object! port! find any-type! struct! (make typeset! [number! integer!]) = number!]) = reduce [true true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
