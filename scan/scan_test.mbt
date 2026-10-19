///|
fn load(source : String) -> @value.Cell raise {
  match @scan.transcode(source, @value.Symbols::new()) {
    Ok(cell) => cell
    Err(error) => fail(error.id())
  }
}

///|
fn spell(cell : @value.Cell) -> (String, @value.Datatype)? {
  match cell {
    @value.Sym(kind, lexeme) => Some((lexeme.spelling(), kind))
    _ => None
  }
}

///|
test "transcode basic values" {
  // lexer-test.r3:16
  let cell = load("1 + 1")
  let series = cell.series().unwrap()
  assert_eq(series.length(), 3)
  assert_true(series.item(0).unwrap() is @value.Cell::Integer(1L))
  assert_true(spell(series.item(1).unwrap()) is Some(("+", @value.Word)))
  assert_true(series.item(2).unwrap() is @value.Cell::Integer(1L))
  assert_eq(load("").series().unwrap().length(), 0)
}

///|
test "integers, decimals, and bases" {
  // lexer-test.r3:587, 598, 626
  assert_true(
    load("-0").series().unwrap().item(0).unwrap() is @value.Cell::Integer(0L),
  )
  assert_true(
    load("2#11").series().unwrap().item(0).unwrap() is @value.Cell::Integer(3L),
  )
  assert_true(
    load("16#FF").series().unwrap().item(0).unwrap()
    is @value.Cell::Integer(255L),
  )
  assert_true(
    load("16#FFFFFFFFFFFFFFFF").series().unwrap().item(0).unwrap()
    is @value.Cell::Integer(-1L),
  )
  assert_true(
    load("1.5").series().unwrap().item(0).unwrap() is @value.Cell::Decimal(1.5),
  )
  match @scan.transcode("2#12", @value.Symbols::new()) {
    Err(error) => assert_eq(error.id(), "invalid")
    Ok(_) => fail("2#12")
  }
}

///|
test "words, strings, chars, and comments" {
  let cell = load("; note\nx: :y 'z /foo \"ab\" {cd} #\"^(2190)\"")
  let series = cell.series().unwrap()
  assert_true(spell(series.item(0).unwrap()) is Some(("x", @value.SetWord)))
  assert_true(spell(series.item(1).unwrap()) is Some(("y", @value.GetWord)))
  assert_true(spell(series.item(2).unwrap()) is Some(("z", @value.LitWord)))
  assert_true(
    spell(series.item(3).unwrap()) is Some(("foo", @value.Refinement)),
  )
  match series.item(4).unwrap() {
    @value.Seq(text, _) => {
      assert_true(text.datatype() == @value.String)
      assert_eq(text.code(0), Some('a'.to_int()))
      assert_eq(text.code(1), Some('b'.to_int()))
    }
    _ => fail("string")
  }
  match series.item(5).unwrap() {
    @value.Seq(text, _) => assert_eq(text.code(0), Some('c'.to_int()))
    _ => fail("braced")
  }
  assert_true(series.item(6).unwrap() is @value.Cell::Char(0x2190))
}

///|
test "blocks, parens, paths, and binary" {
  // lexer-test.r3:792
  let cell = load("[1 (2) a/b]")
  match cell.series().unwrap().item(0).unwrap() {
    @value.Seq(series, _) => {
      assert_true(series.datatype() == @value.Block)
      assert_true(series.item(0).unwrap() is @value.Cell::Integer(1L))
      match series.item(1).unwrap() {
        @value.Seq(paren, _) => {
          assert_true(paren.datatype() == @value.Paren)
          assert_true(paren.item(0).unwrap() is @value.Cell::Integer(2L))
        }
        _ => fail("paren")
      }
      match series.item(2).unwrap() {
        @value.Seq(path, _) => {
          assert_true(path.datatype() == @value.Path)
          assert_eq(path.length(), 2)
        }
        _ => fail("path")
      }
    }
    _ => fail("block")
  }
  match load("#{0 0}").series().unwrap().item(0).unwrap() {
    @value.Seq(binary, _) => {
      assert_true(binary.datatype() == @value.Binary)
      assert_eq(binary.length(), 1)
      assert_eq(binary.byte_at(0).map(fn(byte) { byte.to_int() }), Some(0))
    }
    _ => fail("binary")
  }
  match load("2#{0000 00 00}").series().unwrap().item(0).unwrap() {
    @value.Seq(binary, _) =>
      assert_eq(binary.byte_at(0).map(fn(byte) { byte.to_int() }), Some(0))
    _ => fail("bits")
  }
}

///|
test "a get-word in a path evaluates as the key" {
  match load("m/:k").series().unwrap().item(0).unwrap() {
    @value.Seq(path, _) => {
      assert_true(path.datatype() == @value.Path)
      assert_true(spell(path.item(1).unwrap()) is Some(("k", @value.GetWord)))
    }
    _ => fail("path")
  }
  match load("m/:k:").series().unwrap().item(0).unwrap() {
    @value.Seq(path, _) => {
      assert_true(path.datatype() == @value.SetPath)
      assert_true(spell(path.item(0).unwrap()) is Some(("m", @value.Word)))
      assert_true(spell(path.item(1).unwrap()) is Some(("k", @value.GetWord)))
    }
    _ => fail("set-path")
  }
  match load("m/:k:/b").series().unwrap().item(0).unwrap() {
    @value.Seq(path, _) => {
      assert_true(path.datatype() == @value.Path)
      assert_eq(path.length(), 3)
      assert_true(spell(path.item(1).unwrap()) is Some(("k", @value.GetWord)))
      assert_true(spell(path.item(2).unwrap()) is Some(("b", @value.Word)))
    }
    _ => fail("continued")
  }
  match load("m/:a:b").series().unwrap().item(0).unwrap() {
    @value.Seq(path, _) =>
      assert_true(spell(path.item(1).unwrap()) is Some(("a:b", @value.GetWord)))
    _ => fail("colon-name")
  }
}

///|
test "unclosed block is missing" {
  match @scan.transcode("[1", @value.Symbols::new()) {
    Err(error) => assert_eq(error.id(), "missing")
    Ok(_) => fail("closed")
  }
}
