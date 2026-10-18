///|
/// `make utype! [[] []]`. The spec must be a block whose first two items are
/// blocks. The body is not evaluated. Anything else is `invalid-arg`.
fn make_utype(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      if utype_spec(series, index) {
        @value.Utype(@value.UtypeValue::new())
      } else {
        raise EvalError::Caused("invalid-arg", "")
      }
    _ => raise EvalError::Caused("invalid-arg", "")
  }
}

///|
fn utype_spec(series : @value.Series, index : Int) -> Bool {
  match (series.item(index), series.item(index + 1)) {
    (Some(spec), Some(body)) => utype_block(spec) && utype_block(body)
    _ => false
  }
}

///|
fn utype_block(cell : @value.Cell) -> Bool {
  match cell {
    @value.Seq(series, _) => series.datatype() == @value.Block
    _ => false
  }
}
