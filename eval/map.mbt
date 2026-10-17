///|
fn to_map(spec : @value.Cell) -> @value.Cell raise EvalError {
  let map = @value.MapValue::make()
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => {
      let count = series.length() - index
      if count % 2 != 0 {
        raise EvalError::Cannot("make")
      }
      let mut cursor = index
      while cursor + 1 < series.length() {
        match (series.item(cursor), series.item(cursor + 1)) {
          (Some(key), Some(value)) => map.put(key, value)
          _ => raise EvalError::Cannot("make")
        }
        cursor = cursor + 2
      }
      @value.Map(map)
    }
    _ => raise EvalError::Cannot("make")
  }
}
