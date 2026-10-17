///|
fn word(
  sym : Int,
  spelling : String,
  datatype : @value.Datatype,
) -> @value.Cell {
  @value.Sym(datatype, @value.Lexeme::make(sym, spelling))
}

///|
fn read_word(cell : @value.Cell) -> @value.Cell? {
  match cell {
    @value.Sym(_, lexeme) => lexeme.read()
    _ => None
  }
}

///|
test "the same symbol uses a different slot in each frame" {
  let symbols = @value.Symbols::new()
  let name = symbols.intern("a")
  let user = @value.Frame::new()
  let user_slot = user.ensure(name)
  user.set(user_slot, @value.Integer(1L)) |> ignore
  let func = @value.Frame::new()
  func.ensure(symbols.intern("x")) |> ignore
  let func_slot = func.ensure(name)
  func.set(func_slot, @value.Integer(2L)) |> ignore
  assert_true(user_slot != func_slot)
  let block = @value.Series::block()
  block.push_item(word(name, "a", @value.Word)) |> ignore
  let cell = @value.Seq(block, 0)
  @bind.bind(cell, user) |> ignore
  assert_true(read_word(block.item(0).unwrap()) is Some(@value.Integer(1L)))
  let earlier = block.item(0).unwrap().snapshot()
  @bind.bind(cell, func) |> ignore
  assert_true(read_word(block.item(0).unwrap()) is Some(@value.Integer(2L)))
  assert_true(read_word(earlier) is Some(@value.Integer(1L)))
  let loose = @bind.bind(word(name, "a", @value.Word), user)
  assert_true(read_word(loose) is Some(@value.Integer(1L)))
  assert_true(read_word(word(name, "a", @value.Word)) is None)
}

///|
test "a miss keeps the binding already on the word" {
  let symbols = @value.Symbols::new()
  let name = symbols.intern("a")
  let user = @value.Frame::new()
  let slot = user.ensure(name)
  user.set(slot, @value.Integer(1L)) |> ignore
  let block = @value.Series::block()
  block.push_item(word(name, "a", @value.Word)) |> ignore
  let cell = @value.Seq(block, 0)
  @bind.bind(cell, user) |> ignore
  let other = @value.Frame::new()
  other.ensure(symbols.intern("b")) |> ignore
  @bind.bind(cell, other) |> ignore
  assert_true(read_word(block.item(0).unwrap()) is Some(@value.Integer(1L)))
}

///|
test "binding walks nested blocks and paths from the current index" {
  let symbols = @value.Symbols::new()
  let name = symbols.intern("a")
  let other = symbols.intern("b")
  let user = @value.Frame::new()
  let slot = user.ensure(name)
  user.set(slot, @value.Integer(1L)) |> ignore
  let inner = @value.Series::block()
  inner.push_item(word(name, "a", @value.SetWord)) |> ignore
  let path = @value.Series::path()
  path.push_item(word(name, "a", @value.Word)) |> ignore
  path.push_item(word(other, "b", @value.Word)) |> ignore
  let block = @value.Series::block()
  block.push_item(word(name, "a", @value.GetWord)) |> ignore
  block.push_item(@value.Seq(inner, 0)) |> ignore
  block.push_item(@value.Seq(path, 0)) |> ignore
  block.push_item(word(name, "a", @value.LitWord)) |> ignore
  @bind.bind(@value.Seq(block, 1), user) |> ignore
  assert_true(read_word(block.item(0).unwrap()) is None)
  assert_true(read_word(inner.item(0).unwrap()) is Some(@value.Integer(1L)))
  assert_true(read_word(path.item(0).unwrap()) is Some(@value.Integer(1L)))
  assert_true(read_word(path.item(1).unwrap()) is None)
  assert_true(read_word(block.item(3).unwrap()) is Some(@value.Integer(1L)))
}

///|
test "a block that contains itself is bound once" {
  let symbols = @value.Symbols::new()
  let name = symbols.intern("a")
  let user = @value.Frame::new()
  let slot = user.ensure(name)
  user.set(slot, @value.Integer(1L)) |> ignore
  let block = @value.Series::block()
  let cell = @value.Seq(block, 0)
  block.push_item(cell) |> ignore
  block.push_item(word(name, "a", @value.Refinement)) |> ignore
  @bind.bind(cell, user) |> ignore
  assert_true(read_word(block.item(1).unwrap()) is Some(@value.Integer(1L)))
}
