///|
pub struct Frame {
  slots : Array[Cell]
  sym_to_slot : Map[Int, Int]
}

///|
pub fn Frame::new() -> Frame {
  { slots: [], sym_to_slot: Map([]), }
}

///|
/// Returns the existing slot for `sym`, without creating one.
pub fn Frame::find(self : Frame, sym : Int) -> Int? {
  self.sym_to_slot.get(sym)
}

///|
/// Returns the slot index for `sym`, appending an unset slot on first use.
pub fn Frame::ensure(self : Frame, sym : Int) -> Int {
  match self.sym_to_slot.get(sym) {
    Some(index) => index
    None => {
      let index = self.slots.length()
      self.slots.push(Unset)
      self.sym_to_slot.set(sym, index)
      index
    }
  }
}

///|
pub fn Frame::get(self : Frame, index : Int) -> Cell? {
  self.slots.get(index)
}

///|
pub fn Frame::set(self : Frame, index : Int, cell : Cell) -> Unit {
  self.slots[index] = cell
}

///|
pub fn Frame::length(self : Frame) -> Int {
  self.slots.length()
}
