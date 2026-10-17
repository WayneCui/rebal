///|
/// Keys keep the order they were first written. A later put of the same key replaces the value.
pub struct MapValue {
  keys : Array[Cell]
  values : Array[Cell]
}

///|
pub fn MapValue::make() -> MapValue {
  { keys: [], values: [], }
}

///|
pub fn MapValue::length(self : MapValue) -> Int {
  self.keys.length()
}

///|
pub fn MapValue::key(self : MapValue, index : Int) -> Cell? {
  self.keys.get(index)
}

///|
pub fn MapValue::value(self : MapValue, index : Int) -> Cell? {
  self.values.get(index)
}

///|
pub fn MapValue::get(self : MapValue, key : Cell) -> Cell? {
  match self.find(key) {
    Some(index) => self.values.get(index)
    None => None
  }
}

///|
pub fn MapValue::put(self : MapValue, key : Cell, value : Cell) -> Unit {
  match self.find(key) {
    Some(index) => self.values[index] = value
    None => {
      self.keys.push(key)
      self.values.push(value)
    }
  }
}

///|
pub fn MapValue::same(self : MapValue, other : MapValue) -> Bool {
  if self.keys.length() != other.keys.length() {
    false
  } else {
    let mut ok = true
    for index in 0..<self.keys.length() {
      match (self.keys.get(index), other.keys.get(index)) {
        (Some(left), Some(right)) => if !left.equal(right) { ok = false }
        _ => ok = false
      }
      match (self.values.get(index), other.values.get(index)) {
        (Some(left), Some(right)) => if !left.equal(right) { ok = false }
        _ => ok = false
      }
    }
    ok
  }
}

///|
fn MapValue::find(self : MapValue, key : Cell) -> Int? {
  let mut found : Int? = None
  let mut index = 0
  while found is None && index < self.keys.length() {
    match self.keys.get(index) {
      Some(stored) => if stored.equal(key) { found = Some(index) }
      None => ()
    }
    index = index + 1
  }
  found
}
