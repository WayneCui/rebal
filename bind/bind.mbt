///|
/// Binds words in `cell` to slots that already exist on `frame`.
/// A hit replaces that lexeme. A miss keeps the binding it already has.
pub fn bind(cell : @value.Cell, frame : @value.Frame) -> @value.Cell {
  match cell {
    @value.Sym(datatype, lexeme) => rebound(datatype, lexeme, frame)
    @value.Seq(series, index) => {
      bind_series(series, index, frame, [])
      cell
    }
    _ => cell
  }
}

///|
fn rebound(
  datatype : @value.Datatype,
  lexeme : @value.Lexeme,
  frame : @value.Frame,
) -> @value.Cell {
  match frame.find(lexeme.sym()) {
    Some(slot) =>
      @value.Sym(datatype, lexeme.with_binding(@value.Bound(frame, slot)))
    None => @value.Sym(datatype, lexeme)
  }
}

///|
fn holds_values(series : @value.Series) -> Bool {
  let datatype = series.datatype()
  datatype == @value.Block ||
  datatype == @value.Paren ||
  datatype == @value.Path ||
  datatype == @value.SetPath
}

///|
fn visiting(stack : Array[@value.Series], series : @value.Series) -> Bool {
  let mut index = 0
  let mut found = false
  while index < stack.length() && !found {
    if physical_equal(stack[index], series) {
      found = true
    }
    index = index + 1
  }
  found
}

///|
fn bind_series(
  series : @value.Series,
  index : Int,
  frame : @value.Frame,
  stack : Array[@value.Series],
) -> Unit {
  if holds_values(series) && !visiting(stack, series) {
    stack.push(series)
    let mut cursor = if index < 0 { 0 } else { index }
    while cursor < series.length() {
      match series.item(cursor) {
        Some(@value.Sym(datatype, lexeme)) =>
          match frame.find(lexeme.sym()) {
            Some(slot) =>
              series.set_item(
                cursor,
                @value.Sym(
                  datatype,
                  lexeme.with_binding(@value.Bound(frame, slot)),
                ),
              )
              |> ignore
            None => ()
          }
        Some(@value.Seq(nested, nested_index)) =>
          bind_series(nested, nested_index, frame, stack)
        _ => ()
      }
      cursor = cursor + 1
    }
    stack.remove(stack.length() - 1) |> ignore
  }
}
