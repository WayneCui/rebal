///|
/// A series that is not at its head molds as `#(string! "abc" 2)`.
/// The text inside is the whole series, and the integer is the 1-based index.
pub fn mold_all_text(cell : @value.Cell) -> String {
  match cell {
    @value.Seq(series, index) if index > 0 && mold_positioned(series.datatype()) =>
      mold_position(series, index)
    _ => mold_text(cell)
  }
}

///|
fn mold_positioned(datatype : @value.Datatype) -> Bool {
  datatype == @value.String ||
  datatype == @value.Binary ||
  datatype == @value.Block
}

///|
fn mold_position(series : @value.Series, index : Int) -> String {
  let buf = StringBuilder()
  buf.write_string("#(")
  buf.write_string(type_name(series.datatype()))
  buf.write_char(' ')
  buf.write_string(mold_text(@value.Seq(series, 0)))
  buf.write_char(' ')
  buf.write_string((index + 1).to_string())
  buf.write_char(')')
  buf.to_string()
}
