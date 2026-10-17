///|
fn to_bitset(spec : @value.Cell) -> @value.Cell raise EvalError {
  let bits = @value.Bitset::make()
  fill_bitset(bits, spec)
  @value.Bitset(bits)
}

///|
fn fill_bitset(
  bits : @value.Bitset,
  spec : @value.Cell,
) -> Unit raise EvalError {
  match spec {
    @value.Char(code) => bits.insert(code)
    @value.Integer(n) => insert_code(bits, n)
    @value.Seq(series, index) if series.datatype() == @value.String =>
      for cursor in index..<series.length() {
        match series.code(cursor) {
          Some(code) => bits.insert(code)
          None => ()
        }
      }
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren =>
      fill_bitset_block(bits, series, index)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn fill_bitset_block(
  bits : @value.Bitset,
  series : @value.Series,
  index : Int,
) -> Unit raise EvalError {
  let mut cursor = index
  while cursor < series.length() {
    match series.item(cursor) {
      Some(item) =>
        if is_dash(item) && cursor + 1 < series.length() {
          match (scalar_before(series, cursor), series.item(cursor + 1)) {
            (Some(start), Some(end)) =>
              match scalar_code(end) {
                Some(last) => {
                  if last < start {
                    raise EvalError::Cannot("make")
                  }
                  bits.fill(start, last)
                  cursor = cursor + 2
                }
                None => raise EvalError::Cannot("make")
              }
            _ => raise EvalError::Cannot("make")
          }
        } else {
          fill_bitset(bits, item)
          cursor = cursor + 1
        }
      None => cursor = cursor + 1
    }
  }
}

///|
fn scalar_before(series : @value.Series, dash : Int) -> Int? {
  if dash <= 0 {
    None
  } else {
    match series.item(dash - 1) {
      Some(item) => scalar_code(item)
      None => None
    }
  }
}

///|
fn scalar_code(cell : @value.Cell) -> Int? {
  match cell {
    @value.Char(code) => Some(code)
    @value.Integer(n) => if n >= 0L { Some(n.to_int()) } else { None }
    _ => None
  }
}

///|
fn insert_code(bits : @value.Bitset, n : Int64) -> Unit raise EvalError {
  if n < 0L {
    raise EvalError::Cannot("make")
  }
  bits.insert(n.to_int())
}

///|
fn is_dash(cell : @value.Cell) -> Bool {
  match cell {
    @value.Sym(_, lexeme) => lexeme.spelling() == "-"
    _ => false
  }
}
