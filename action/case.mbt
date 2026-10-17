///|
pub fn lowercase(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "lowercase", fn(value) { @series.lowercase(value) })
}

///|
pub fn uppercase(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "uppercase", fn(value) { @series.uppercase(value) })
}

///|
pub fn deline(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "deline", fn(value) { @series.deline(value) })
}

///|
pub fn enline(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "enline", fn(value) { @series.enline(value) })
}

///|
pub fn detab(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "detab", fn(value) { @series.detab(value) })
}

///|
pub fn entab(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "entab", fn(value) { @series.entab(value) })
}

///|
pub fn dehex(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "dehex", fn(value) { @series.dehex(value) })
}

///|
pub fn enhex(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "enhex", fn(value) { @series.enhex(value) })
}

///|
pub fn enhex_uri(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed_text(cell, "enhex", fn(value) { @series.enhex_with(value, true) })
}

///|
fn changed_text(
  cell : @value.Cell,
  name : String,
  edit : (@value.Cell) -> @value.Cell?,
) -> Result[@value.Cell, ActionError] {
  match edit(cell) {
    Some(value) => Ok(value)
    None => Err(Cannot(name))
  }
}
