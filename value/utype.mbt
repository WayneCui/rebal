///|
/// A user type. Comparison is never true, including a value with itself.
pub struct UtypeValue {
  kept : Int
}

///|
pub fn UtypeValue::new() -> UtypeValue {
  { kept: 0, }
}
