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
