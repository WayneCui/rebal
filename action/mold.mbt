///|
pub fn mold(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  Ok(@mold.cell(@mold.mold_text(cell)))
}

///|
pub fn form(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  Ok(@mold.cell(@mold.form_text(cell)))
}
