///|
/// `release` frees a handle. A later use of that same handle fails.
/// Anything else returns `false`.
fn perform_release(value : @value.Cell) -> @value.Cell {
  match value {
    @value.Handle(handle) => {
      handle.release()
      @value.Logic(true)
    }
    _ => @value.Logic(false)
  }
}
