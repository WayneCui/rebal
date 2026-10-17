///|
pub struct Frame {
  slots : Array[Cell]
  sym_to_slot : Map[Int, Int]
  locked : Array[Bool]
}

///|
pub fn Frame::new() -> Frame {
  { slots: [], sym_to_slot: Map([]), locked: [], }
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
      self.locked.push(false)
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
/// Returns false when the slot is protected. The value stays as it was.
pub fn Frame::set(self : Frame, index : Int, cell : Cell) -> Bool {
  if self.is_locked(index) {
    false
  } else {
    self.slots[index] = cell
    true
  }
}

///|
pub fn Frame::lock(self : Frame, index : Int, flag : Bool) -> Unit {
  if index >= 0 && index < self.locked.length() {
    self.locked[index] = flag
  }
}

///|
pub fn Frame::is_locked(self : Frame, index : Int) -> Bool {
  match self.locked.get(index) {
    Some(flag) => flag
    None => false
  }
}

///|
pub fn Frame::length(self : Frame) -> Int {
  self.slots.length()
}

///|
/// A new frame with the same words and empty slots. The original stays as it is.
pub fn Frame::copy_shape(self : Frame) -> Frame {
  let slots : Array[Cell] = []
  let locked : Array[Bool] = []
  for _ in 0..<self.slots.length() {
    slots.push(Unset)
    locked.push(false)
  }
  { slots, sym_to_slot: self.sym_to_slot.copy(), locked, }
}
