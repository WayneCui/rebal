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
/// Rebinds only the words that point at `from`. Words bound anywhere else,
/// and words `to` does not have, stay as they are. Used when an object is
/// cloned, so its blocks see the clone instead of the prototype.
pub fn rebind(
  cell : @value.Cell,
  from : @value.Frame,
  to : @value.Frame,
) -> @value.Cell {
  match cell {
    @value.Sym(datatype, lexeme) => rerouted(datatype, lexeme, from, to)
    @value.Seq(series, index) => {
      rebind_series(series, index, from, to, [])
      cell
    }
    _ => cell
  }
}

///|
fn rerouted(
  datatype : @value.Datatype,
  lexeme : @value.Lexeme,
  from : @value.Frame,
  to : @value.Frame,
) -> @value.Cell {
  match lexeme.binding() {
    @value.Bound(frame, _) if physical_equal(frame, from) =>
      match to.find(lexeme.sym()) {
        Some(slot) =>
          @value.Sym(datatype, lexeme.with_binding(@value.Bound(to, slot)))
        None => @value.Sym(datatype, lexeme)
      }
    _ => @value.Sym(datatype, lexeme)
  }
}

///|
fn rebind_series(
  series : @value.Series,
  index : Int,
  from : @value.Frame,
  to : @value.Frame,
  stack : Array[@value.Series],
) -> Unit {
  if holds_values(series) && !visiting(stack, series) {
    stack.push(series)
    let mut cursor = if index < 0 { 0 } else { index }
    while cursor < series.length() {
      match series.item(cursor) {
        Some(@value.Sym(datatype, lexeme)) =>
          match lexeme.binding() {
            @value.Bound(frame, _) if physical_equal(frame, from) =>
              match to.find(lexeme.sym()) {
                Some(slot) =>
                  series.set_item(
                    cursor,
                    @value.Sym(
                      datatype,
                      lexeme.with_binding(@value.Bound(to, slot)),
                    ),
                  )
                  |> ignore
                None => ()
              }
            _ => ()
          }
        Some(@value.Seq(nested, nested_index)) =>
          rebind_series(nested, nested_index, from, to, stack)
        _ => ()
      }
      cursor = cursor + 1
    }
    stack.remove(stack.length() - 1) |> ignore
  }
}

///|
/// Clears bindings in `cell`. The series is updated in place.
pub fn unbind(cell : @value.Cell) -> @value.Cell {
  match cell {
    @value.Sym(datatype, lexeme) =>
      @value.Sym(datatype, lexeme.with_binding(@value.Unbound))
    @value.Seq(series, index) => {
      unbind_series(series, index, [])
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

///|
fn unbind_series(
  series : @value.Series,
  index : Int,
  stack : Array[@value.Series],
) -> Unit {
  if holds_values(series) && !visiting(stack, series) {
    stack.push(series)
    let mut cursor = if index < 0 { 0 } else { index }
    while cursor < series.length() {
      match series.item(cursor) {
        Some(@value.Sym(datatype, lexeme)) =>
          series.set_item(
            cursor,
            @value.Sym(datatype, lexeme.with_binding(@value.Unbound)),
          )
          |> ignore
        Some(@value.Seq(nested, nested_index)) =>
          unbind_series(nested, nested_index, stack)
        _ => ()
      }
      cursor = cursor + 1
    }
    stack.remove(stack.length() - 1) |> ignore
  }
}
