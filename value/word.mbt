///|
pub(all) enum Binding {
  Unbound
  Bound(Frame, Int)
}

///|
/// One word cell. Replacing the series slot rebinds; older copies keep their lexeme.
pub struct Lexeme {
  sym : Int
  spelling : String
  binding : Binding
}

///|
pub fn Lexeme::make(sym : Int, spelling : String) -> Lexeme {
  { sym, spelling, binding: Unbound, }
}

///|
pub fn Lexeme::spelling(self : Lexeme) -> String {
  self.spelling
}

///|
pub fn Lexeme::sym(self : Lexeme) -> Int {
  self.sym
}

///|
pub fn Lexeme::with_binding(self : Lexeme, binding : Binding) -> Lexeme {
  { sym: self.sym, spelling: self.spelling, binding, }
}

///|
pub fn Lexeme::snapshot(self : Lexeme) -> Lexeme {
  { sym: self.sym, spelling: self.spelling, binding: self.binding, }
}

///|
pub fn Lexeme::read(self : Lexeme) -> Cell? {
  match self.binding {
    Unbound => None
    Bound(frame, index) => frame.get(index)
  }
}
