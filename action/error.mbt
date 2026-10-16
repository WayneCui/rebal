///|
pub enum ActionError {
  Cannot(String)
}

///|
pub fn ActionError::id(self : ActionError) -> String {
  match self {
    Cannot(_) => "cannot"
  }
}
