///|
fn text_cell(source : String) -> @value.Cell {
  let series = @value.Series::text()
  for char in source {
    series.push_code(char.to_int()) |> ignore
  }
  @value.Seq(series, 0)
}

///|
fn block_cell(items : Array[@value.Cell]) -> @value.Cell {
  let series = @value.Series::block()
  for item in items {
    series.push_item(item) |> ignore
  }
  @value.Seq(series, 0)
}

///|
test "numbers chars and strings compare with coercion" {
  assert_true(@action.equal(@value.Integer(1L), @value.Decimal(1.0)))
  assert_true(
    @action.equal(@value.Char('A'.to_int()), @value.Char('a'.to_int())),
  )
  assert_true(@action.equal(@value.Char('A'.to_int()), @value.Integer(65L)))
  assert_true(@action.equal(text_cell("A"), text_cell("a")))
  assert_true(
    @action.equal(
      block_cell([@value.Integer(1L)]),
      block_cell([@value.Decimal(1.0)]),
    ),
  )
  match @action.lesser(@value.Char('A'.to_int()), @value.Char('a'.to_int())) {
    Ok(flag) => assert_true(flag)
    Err(_) => fail("char order")
  }
  match @action.lesser(text_cell("A"), text_cell("a")) {
    Ok(flag) => assert_true(flag)
    Err(_) => fail("string order")
  }
  match @action.lesser(@value.Integer(1L), text_cell("a")) {
    Err(error) => assert_eq(error.id(), "cannot")
    Ok(_) => fail("mismatch")
  }
  match @action.greater(@value.Integer(2L), @value.Integer(1L)) {
    Ok(flag) => assert_true(flag)
    Err(_) => fail("greater")
  }
}
