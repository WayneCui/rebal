///|
/// Element width of a vector. Integer kinds share one comparison.
pub(all) enum VectorKind {
  Int8
  Int16
  Int32
  Int64
  Uint8
  Uint16
  Uint32
  Uint64
  Float32
  Float64
}

///|
pub struct Vector {
  kind : VectorKind
  ints : Array[Int64]
  floats : Array[Double]
}

///|
pub fn VectorKind::float(self : VectorKind) -> Bool {
  match self {
    Float32 | Float64 => true
    _ => false
  }
}

///|
pub fn VectorKind::label(self : VectorKind) -> String {
  match self {
    Int8 => "int8!"
    Int16 => "int16!"
    Int32 => "int32!"
    Int64 => "int64!"
    Uint8 => "uint8!"
    Uint16 => "uint16!"
    Uint32 => "uint32!"
    Uint64 => "uint64!"
    Float32 => "float32!"
    Float64 => "float64!"
  }
}

///|
pub fn Vector::ints(kind : VectorKind, ints : Array[Int64]) -> Vector {
  { kind, ints, floats: [], }
}

///|
pub fn Vector::floats(kind : VectorKind, floats : Array[Double]) -> Vector {
  { kind, ints: [], floats, }
}

///|
pub fn Vector::kind(self : Vector) -> VectorKind {
  self.kind
}

///|
pub fn Vector::length(self : Vector) -> Int {
  if self.kind.float() {
    self.floats.length()
  } else {
    self.ints.length()
  }
}

///|
pub fn Vector::at(self : Vector, index : Int) -> Cell? {
  if index < 1 || index > self.length() {
    None
  } else if self.kind.float() {
    Some(Decimal(self.floats[index - 1]))
  } else {
    Some(Integer(self.ints[index - 1]))
  }
}

///|
/// Integer vectors compare by value across widths. Floats compare by value too.
/// A float and an integer vector are not the same kind of number.
pub fn Vector::same(self : Vector, other : Vector) -> Bool {
  if self.kind.float() != other.kind.float() || self.length() != other.length() {
    false
  } else if self.kind.float() {
    let mut ok = true
    for index in 0..<self.floats.length() {
      if self.floats[index] != other.floats[index] {
        ok = false
      }
    }
    ok
  } else {
    let mut ok = true
    for index in 0..<self.ints.length() {
      if self.ints[index] != other.ints[index] {
        ok = false
      }
    }
    ok
  }
}

///|
pub fn Vector::mismatched(self : Vector, other : Vector) -> Bool {
  self.kind.float() != other.kind.float()
}
