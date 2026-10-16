///|
fn block_of(cells : Array[@value.Cell]) -> @value.Cell {
  let series = @value.Series::block()
  for cell in cells {
    series.push_item(cell) |> ignore
  }
  @value.Seq(series, 0)
}

///|
fn text_of(codes : Array[Int]) -> @value.Cell {
  let series = @value.Series::text()
  for code in codes {
    series.push_code(code) |> ignore
  }
  @value.Seq(series, 0)
}

///|
test "self-append copies the block before extending it" {
  // series-test.r3:756
  let block = block_of([@value.Cell::Integer(1L)])
  let appended = @series.append(block, block).unwrap()
  let expected = block_of([@value.Cell::Integer(1L), @value.Cell::Integer(1L)])
  assert_true(appended.equal(expected))
  assert_true(block.equal(expected))
}

///|
test "append char and a wide char" {
  // series-test.r3:763
  let empty = text_of([])
  let letter = @series.append(empty, @value.Cell::Char('a'.to_int())).unwrap()
  assert_true(letter.equal(text_of(['a'.to_int()])))
  let wide = @series.append(text_of([]), @value.Cell::Char(0x2190)).unwrap()
  assert_true(wide.equal(text_of([0x2190])))
}

///|
test "find integer digit in a string" {
  // series-test.r3:127
  let found = @series.find(
    text_of(['1'.to_int(), '2'.to_int(), '3'.to_int()]),
    @value.Cell::Integer(2L),
  )
  assert_true(found.equal(text_of(['2'.to_int(), '3'.to_int()])))
}

///|
test "next head tail index and length" {
  let block = block_of([@value.Cell::Integer(1L), @value.Cell::Integer(2L)])
  assert_eq(@series.index(block), Some(1))
  assert_eq(@series.length(block), Some(2))
  assert_eq(@series.is_tail(block), Some(false))
  let stepped = @series.next(block).unwrap()
  assert_eq(@series.index(stepped), Some(2))
  assert_eq(@series.index(block), Some(1))
  let end = @series.tail(block).unwrap()
  assert_eq(@series.length(end), Some(0))
  assert_eq(@series.index(end), Some(3))
  assert_eq(@series.is_tail(end), Some(true))
  assert_eq(@series.index(@series.head(stepped).unwrap()), Some(1))
}

///|
test "pick poke insert and remove" {
  // series-test.r3:1460
  let block = block_of([
    @value.Cell::Integer(1L),
    @value.Cell::Integer(2L),
    @value.Cell::Integer(3L),
  ])
  assert_true(@series.pick(block, 2) is @value.Cell::Integer(2L))
  @series.poke(block, 2, @value.Cell::Integer(9L)) |> ignore
  assert_true(@series.pick(block, 2) is @value.Cell::Integer(9L))
  let removed = @series.remove(block).unwrap()
  let rest = block_of([@value.Cell::Integer(9L), @value.Cell::Integer(3L)])
  assert_true(removed.equal(rest))
  assert_true(block.equal(rest))
  let inserted = @series.insert(block, @value.Cell::Integer(7L)).unwrap()
  assert_true(
    block.equal(
      block_of([
        @value.Cell::Integer(7L),
        @value.Cell::Integer(9L),
        @value.Cell::Integer(3L),
      ]),
    ),
  )
  assert_eq(@series.index(inserted), Some(2))
}

///|
test "copy does not share later appends" {
  let block = block_of([@value.Cell::Integer(1L)])
  let copied = @series.copy(block).unwrap()
  @series.append(block, @value.Cell::Integer(2L)) |> ignore
  assert_true(copied.equal(block_of([@value.Cell::Integer(1L)])))
  assert_true(
    block.equal(block_of([@value.Cell::Integer(1L), @value.Cell::Integer(2L)])),
  )
}
