///|
fn block(items : Array[@value.Cell]) -> @value.Cell {
  let series = @value.Series::block()
  for item in items {
    series.push_item(item) |> ignore
  }
  @value.Seq(series, 0)
}

///|
fn text(source : String) -> @value.Cell {
  let series = @value.Series::text()
  for char in source {
    series.push_code(char.to_int()) |> ignore
  }
  @value.Seq(series, 0)
}

///|
test "arithmetic promotes integers and decimals" {
  match @action.add(@value.Integer(1L), @value.Integer(2L)) {
    Ok(cell) => assert_true(cell is @value.Integer(3L))
    Err(_) => fail("add")
  }
  match @action.add(@value.Integer(1L), @value.Decimal(2.5)) {
    Ok(cell) => assert_true(cell is @value.Decimal(3.5))
    Err(_) => fail("promote")
  }
  match @action.multiply(@value.Decimal(1.5), @value.Integer(2L)) {
    Ok(cell) => assert_true(cell is @value.Decimal(3.0))
    Err(_) => fail("multiply")
  }
  match @action.subtract(@value.Integer(1L), @value.Integer(4L)) {
    Ok(cell) => assert_true(cell is @value.Integer(-3L))
    Err(_) => fail("subtract")
  }
  match @action.add(@value.Integer(1L), @value.None) {
    Err(error) => assert_eq(error.id(), "cannot")
    Ok(_) => fail("type")
  }
}

///|
test "series actions follow the series package" {
  let series = block([@value.Integer(1L), @value.Integer(2L)])
  match @action.first(series) {
    Ok(cell) => assert_true(cell is @value.Integer(1L))
    Err(_) => fail("first")
  }
  match @action.length(series) {
    Ok(cell) => assert_true(cell is @value.Integer(2L))
    Err(_) => fail("length")
  }
  let digit = '2'.to_int()
  match @action.find(text("123"), @value.Integer(2L)) {
    Ok(found) =>
      match @action.first(found) {
        Ok(cell) =>
          match cell {
            @value.Char(code) => assert_eq(code, digit)
            _ => fail("digit")
          }
        Err(_) => fail("digit")
      }
    Err(_) => fail("find")
  }
  let copied = match @action.copy(series) {
    Ok(cell) => cell
    Err(_) => fail("copy")
  }
  @action.append(series, @value.Integer(3L)) |> ignore
  match @action.length(copied) {
    Ok(cell) => assert_true(cell is @value.Integer(2L))
    Err(_) => fail("copied")
  }
  match @action.insert(series, @value.Integer(9L)) {
    Ok(_) =>
      match @action.first(series) {
        Ok(cell) => assert_true(cell is @value.Integer(9L))
        Err(_) => fail("inserted")
      }
    Err(_) => fail("insert")
  }
  match @action.remove(series) {
    Ok(_) =>
      match @action.first(series) {
        Ok(cell) => assert_true(cell is @value.Integer(1L))
        Err(_) => fail("removed")
      }
    Err(_) => fail("remove")
  }
  match @action.length(@value.Integer(1L)) {
    Err(error) => assert_eq(error.id(), "cannot")
    Ok(_) => fail("length type")
  }
}
