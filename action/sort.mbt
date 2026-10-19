///|
/// Sort from the current index to the tail. `reverse` puts the greater values first.
pub fn sort(
  cell : @value.Cell,
  reverse : Bool,
) -> Result[@value.Cell, ActionError] {
  match cell {
    @value.None => Ok(@value.None)
    @value.Seq(series, index) =>
      match series.datatype() {
        @value.Block | @value.Paren | @value.Path | @value.SetPath =>
          match sort_items(series, index, reverse) {
            Ok(_) => Ok(cell)
            Err(error) => Err(error)
          }
        @value.String => {
          sort_codes(series, index, reverse)
          Ok(cell)
        }
        _ => Err(Cannot("sort"))
      }
    _ => Err(Cannot("sort"))
  }
}

///|
/// Sort records of `size` items by the first cell of each record.
pub fn sort_skip(
  cell : @value.Cell,
  size : Int,
  reverse : Bool,
) -> Result[@value.Cell, ActionError] {
  match cell {
    @value.None => Ok(@value.None)
    @value.Seq(series, index) =>
      match series.datatype() {
        @value.Block | @value.Paren =>
          match sort_records(series, index, size, reverse) {
            Ok(_) => Ok(cell)
            Err(error) => Err(error)
          }
        _ => Err(Cannot("sort"))
      }
    _ => Err(Cannot("sort"))
  }
}

///|
fn sort_records(
  series : @value.Series,
  index : Int,
  size : Int,
  reverse : Bool,
) -> Result[Unit, ActionError] {
  let start = if index < 0 { 0 } else { index }
  let length = series.length()
  if size <= 0 || (length - start) % size != 0 {
    return Err(Cannot("sort"))
  }
  let count = (length - start) / size
  let keys : Array[@value.Cell] = []
  let rows : Array[Array[@value.Cell]] = []
  for r in 0..<count {
    let row : Array[@value.Cell] = []
    for c in 0..<size {
      match series.item(start + r * size + c) {
        Some(item) => row.push(item.snapshot())
        None => row.push(@value.None)
      }
    }
    keys.push(row[0])
    rows.push(row)
  }
  for i in 1..<count {
    let key = keys[i]
    let row = rows[i]
    let mut gap = i
    let mut shifting = true
    while shifting && gap > 0 {
      match before(key, keys[gap - 1], reverse) {
        Ok(true) => {
          keys[gap] = keys[gap - 1]
          rows[gap] = rows[gap - 1]
          gap = gap - 1
        }
        Ok(false) => shifting = false
        Err(error) => return Err(error)
      }
    }
    keys[gap] = key
    rows[gap] = row
  }
  for r in 0..<count {
    for c in 0..<size {
      series.set_item(start + r * size + c, rows[r][c]) |> ignore
    }
  }
  Ok(())
}

///|
fn sort_items(
  series : @value.Series,
  index : Int,
  reverse : Bool,
) -> Result[Unit, ActionError] {
  let length = series.length()
  for i in (index + 1)..<length {
    match series.item(i) {
      Some(key) => {
        let mut gap = i
        let mut shifting = true
        while shifting && gap > index {
          match series.item(gap - 1) {
            Some(earlier) =>
              match before(key, earlier, reverse) {
                Ok(true) => {
                  series.set_item(gap, earlier) |> ignore
                  gap = gap - 1
                }
                Ok(false) => shifting = false
                Err(error) => return Err(error)
              }
            None => shifting = false
          }
        }
        series.set_item(gap, key) |> ignore
      }
      None => ()
    }
  }
  Ok(())
}

///|
fn sort_codes(series : @value.Series, index : Int, reverse : Bool) -> Unit {
  let length = series.length()
  for i in (index + 1)..<length {
    match series.code(i) {
      Some(key) => {
        let mut gap = i
        let mut shifting = true
        while shifting && gap > index {
          match series.code(gap - 1) {
            Some(earlier) =>
              if (if reverse { key > earlier } else { key < earlier }) {
                series.set_code(gap, earlier) |> ignore
                gap = gap - 1
              } else {
                shifting = false
              }
            None => shifting = false
          }
        }
        series.set_code(gap, key) |> ignore
      }
      None => ()
    }
  }
}

///|
fn before(
  key : @value.Cell,
  earlier : @value.Cell,
  reverse : Bool,
) -> Result[Bool, ActionError] {
  match order(key, earlier, 0) {
    Ok(n) => Ok(if reverse { n > 0 } else { n < 0 })
    Err(_) => Err(Cannot("sort"))
  }
}
