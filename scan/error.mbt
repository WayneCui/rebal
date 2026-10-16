///|
pub enum ScanError {
  Missing(String)
  Invalid(String)
}

///|
pub fn ScanError::id(self : ScanError) -> String {
  match self {
    Missing(_) => "missing"
    Invalid(_) => "invalid"
  }
}
