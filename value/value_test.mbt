///|
test "intern folds ascii case" {
  let symbols = @value.Symbols::new()
  let upper = symbols.intern("Print")
  let lower = symbols.intern("print")
  assert_eq(upper, lower)
  assert_eq(symbols.canon(upper), "print")
  let word = @value.Lexeme::make(upper, "Print")
  assert_eq(word.spelling(), "Print")
}

///|
test "shared buffer is visible through both cells" {
  let series = @value.Series::block()
  let left = @value.Seq(series, 0)
  let right = @value.Seq(series, 0)
  assert_true(series.push_item(@value.Integer(1L)))
  assert_true(left.same(right))
  assert_eq(series.length(), 1)
  let other = @value.Series::block()
  other.push_item(@value.Integer(1L)) |> ignore
  assert_true(left.equal(@value.Seq(other, 0)))
}

///|
test "equal starts at the cell index" {
  let series = @value.Series::block()
  series.push_item(@value.Integer(1L)) |> ignore
  series.push_item(@value.Integer(2L)) |> ignore
  let head = @value.Seq(series, 0)
  let tail = @value.Seq(series, 1)
  let only_two = @value.Series::block()
  only_two.push_item(@value.Integer(2L)) |> ignore
  assert_false(head.equal(tail))
  assert_true(tail.equal(@value.Seq(only_two, 0)))
  assert_true(head.same(tail))
  assert_false(head.same(@value.Seq(only_two, 0)))
}

///|
test "rebind replaces the slot and keeps the earlier copy" {
  let symbols = @value.Symbols::new()
  let sym = symbols.intern("x")
  let frame = @value.Frame::new()
  let slot = frame.ensure(sym)
  frame.set(slot, @value.Integer(3L))
  let series = @value.Series::block()
  let original = @value.Sym(@value.Word, @value.Lexeme::make(sym, "x"))
  series.push_item(original) |> ignore
  let copied = series.item(0).unwrap().snapshot()
  let bound = @value.Sym(
    @value.Word,
    @value.Lexeme::make(sym, "x").with_binding(@value.Bound(frame, slot)),
  )
  assert_true(series.set_item(0, bound))
  match copied {
    @value.Sym(_, word) => assert_true(word.read() is None)
    _ => fail("word")
  }
  match series.item(0).unwrap() {
    @value.Sym(_, word) => assert_true(word.read() is Some(@value.Integer(3L)))
    _ => fail("word")
  }
}

///|
test "copy snapshots words and shares nested blocks" {
  let symbols = @value.Symbols::new()
  let sym = symbols.intern("x")
  let inner = @value.Series::block()
  inner.push_item(@value.Integer(1L)) |> ignore
  let outer = @value.Series::block()
  outer.push_item(@value.Sym(@value.Word, @value.Lexeme::make(sym, "x")))
  |> ignore
  outer.push_item(@value.Seq(inner, 0)) |> ignore
  let copied = outer.copy_from(0)
  let frame = @value.Frame::new()
  let slot = frame.ensure(sym)
  let rebound = @value.Sym(
    @value.Word,
    @value.Lexeme::make(sym, "X").with_binding(@value.Bound(frame, slot)),
  )
  outer.set_item(0, rebound) |> ignore
  match copied.item(0) {
    Some(@value.Sym(_, word)) => assert_true(word.read() is None)
    _ => fail("copied word")
  }
  inner.push_item(@value.Integer(2L)) |> ignore
  match copied.item(1) {
    Some(@value.Seq(shared, _)) => assert_eq(shared.length(), 2)
    _ => fail("nested")
  }
}
