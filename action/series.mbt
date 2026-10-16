///|
pub fn append(
  series : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  changed(series, "append", fn(cell) { @series.append(cell, value) })
}

///|
pub fn insert(
  series : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  changed(series, "insert", fn(cell) { @series.insert(cell, value) })
}

///|
pub fn remove(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "remove", fn(cell) { @series.remove(cell) })
}

///|
pub fn copy(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "copy", fn(cell) { @series.copy(cell) })
}

///|
pub fn find(
  series : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  if is_series(series) {
    Ok(@series.find(series, value))
  } else {
    Err(Cannot("find"))
  }
}

///|
pub fn pick(
  series : @value.Cell,
  index : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  if is_series(series) {
    match fit_int(index) {
      Some(n) => Ok(@series.pick(series, n))
      None => Err(Cannot("pick"))
    }
  } else {
    Err(Cannot("pick"))
  }
}

///|
pub fn length(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  match @series.length(series) {
    Some(n) => Ok(@value.Integer(n.to_int64()))
    None => Err(Cannot("length?"))
  }
}

///|
/// `first` is `pick` of 1. An empty series is `none`.
pub fn first(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  if is_series(series) {
    Ok(@series.pick(series, 1))
  } else {
    Err(Cannot("first"))
  }
}

///|
fn changed(
  series : @value.Cell,
  name : String,
  op : (@value.Cell) -> @value.Cell?,
) -> Result[@value.Cell, ActionError] {
  if is_series(series) {
    match op(series) {
      Some(cell) => Ok(cell)
      None => Err(Cannot(name))
    }
  } else {
    Err(Cannot(name))
  }
}

///|
fn is_series(cell : @value.Cell) -> Bool {
  let datatype = cell.datatype()
  datatype == @value.Block ||
  datatype == @value.Paren ||
  datatype == @value.Path ||
  datatype == @value.SetPath ||
  datatype == @value.String ||
  datatype == @value.Binary
}

///|
fn fit_int(cell : @value.Cell) -> Int? {
  match cell {
    @value.Integer(n) =>
      if n >= -2147483648L && n <= 2147483647L {
        Some(n.to_int())
      } else {
        None
      }
    _ => None
  }
}
