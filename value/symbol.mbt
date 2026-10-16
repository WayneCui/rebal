///|
/// ASCII case-folding symbol table. The original spelling lives on each word.
pub struct Symbols {
  canon_to_id : Map[String, Int]
  canon : Array[String]
}

///|
pub fn Symbols::new() -> Symbols {
  { canon_to_id: Map([]), canon: [], }
}

///|
pub fn Symbols::intern(self : Symbols, spelling : String) -> Int {
  let key = spelling.to_lower()
  match self.canon_to_id.get(key) {
    Some(id) => id
    None => {
      let id = self.canon.length()
      self.canon.push(key)
      self.canon_to_id.set(key, id)
      id
    }
  }
}

///|
pub fn Symbols::canon(self : Symbols, sym : Int) -> String {
  self.canon[sym]
}
