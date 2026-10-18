///|
/// `mold/all` keeps a series position. Any other refinement is refused.
fn perform_mold(
  env : Env,
  cell : @value.Cell,
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let mut all = false
  for sym in active {
    if env.symbols.canon(sym) == "all" {
      all = true
    } else {
      raise EvalError::Cannot("mold")
    }
  }
  let text = if all { @mold.mold_all_text(cell) } else { @mold.mold_text(cell) }
  @mold.cell(text)
}
