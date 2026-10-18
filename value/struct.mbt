///|
/// Field type of a struct. `float!` is stored as `float32!`, `double!` as `float64!`.
pub(all) enum StructKind {
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
  Word
} derive(Eq)

///|
pub extend StructKind with Eq::{not_equal, equal}

///|
pub struct StructField {
  name : String
  kind : StructKind
  dimension : Int
  shown : Bool
  ints : Array[Int64]
  floats : Array[Double]
}

///|
pub struct StructValue {
  fields : Array[StructField]
}

///|
pub fn StructKind::label(self : StructKind) -> String {
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
    Word => "word!"
  }
}

///|
pub fn StructKind::bytes(self : StructKind) -> Int {
  match self {
    Int8 | Uint8 => 1
    Int16 | Uint16 => 2
    Int32 | Uint32 | Float32 | Word => 4
    Int64 | Uint64 | Float64 => 8
  }
}

///|
pub fn StructKind::vector_kind(self : StructKind) -> VectorKind {
  match self {
    Int8 => VectorKind::Int8
    Int16 => VectorKind::Int16
    Int32 => VectorKind::Int32
    Int64 => VectorKind::Int64
    Uint8 => VectorKind::Uint8
    Uint16 => VectorKind::Uint16
    Uint32 => VectorKind::Uint32
    Uint64 => VectorKind::Uint64
    Float32 => VectorKind::Float32
    _ => VectorKind::Float64
  }
}

///|
pub fn StructKind::float(self : StructKind) -> Bool {
  match self {
    Float32 | Float64 => true
    _ => false
  }
}

///|
pub fn StructField::make(
  name : String,
  kind : StructKind,
  dimension : Int,
  shown : Bool,
) -> StructField {
  let ints : Array[Int64] = []
  let floats : Array[Double] = []
  let count = if dimension < 1 { 0 } else { dimension }
  if kind.float() {
    for _ in 0..<count {
      floats.push(0.0)
    }
  } else if kind != StructKind::Word {
    for _ in 0..<count {
      ints.push(0L)
    }
  }
  { name, kind, dimension, shown, ints, floats, }
}

///|
pub fn StructValue::make(fields : Array[StructField]) -> StructValue {
  { fields, }
}

///|
pub fn StructValue::length(self : StructValue) -> Int {
  let mut total = 0
  for field in self.fields {
    total = total + field.kind.bytes() * field.dimension
  }
  total
}

///|
pub fn StructValue::count(self : StructValue) -> Int {
  self.fields.length()
}

///|
pub fn StructValue::field(self : StructValue, index : Int) -> StructField {
  self.fields[index]
}

///|
pub fn StructValue::get(self : StructValue, name : String) -> Cell? {
  let key = name.to_lower()
  let mut found : Cell? = None
  for field in self.fields {
    if field.name.to_lower() == key {
      found = Some(field.cell())
    }
  }
  found
}

///|
pub fn StructValue::same(self : StructValue, other : StructValue) -> Bool {
  if self.fields.length() != other.fields.length() {
    false
  } else {
    let mut ok = true
    for index in 0..<self.fields.length() {
      if !self.fields[index].same(other.fields[index]) {
        ok = false
      }
    }
    ok
  }
}

///|
pub fn StructField::name(self : StructField) -> String {
  self.name
}

///|
pub fn StructField::label(self : StructField) -> String {
  self.kind.label()
}

///|
pub fn StructField::shown_dimension(self : StructField) -> Int? {
  if self.shown {
    Some(self.dimension)
  } else {
    None
  }
}

///|
/// A dimension above 1 molds as a block. Zero and one mold as a single value.
pub fn StructField::wide(self : StructField) -> Bool {
  self.dimension > 1
}

///|
pub fn StructField::mold_values(self : StructField) -> Array[Cell] {
  if self.dimension > 1 {
    self.elements()
  } else if self.kind == StructKind::Word {
    [None]
  } else if self.kind.float() {
    [Decimal(0.0)]
  } else {
    [Integer(0L)]
  }
}

///|
fn StructField::cell(self : StructField) -> Cell {
  if self.kind == StructKind::Word {
    if self.dimension == 1 {
      None
    } else {
      none_block(self.dimension)
    }
  } else if self.dimension == 1 {
    if self.kind.float() {
      Decimal(self.floats[0])
    } else {
      Integer(self.ints[0])
    }
  } else if self.kind.float() {
    Vector(Vector::floats(self.kind.vector_kind(), self.floats))
  } else {
    Vector(Vector::ints(self.kind.vector_kind(), self.ints))
  }
}

///|
fn StructField::elements(self : StructField) -> Array[Cell] {
  let out : Array[Cell] = []
  if self.kind == StructKind::Word {
    for _ in 0..<self.dimension {
      out.push(None)
    }
  } else if self.kind.float() {
    for value in self.floats {
      out.push(Decimal(value))
    }
  } else {
    for value in self.ints {
      out.push(Integer(value))
    }
  }
  out
}

///|
fn StructField::same(self : StructField, other : StructField) -> Bool {
  if self.name != other.name ||
    self.kind != other.kind ||
    self.dimension != other.dimension ||
    self.shown != other.shown ||
    self.ints.length() != other.ints.length() ||
    self.floats.length() != other.floats.length() {
    false
  } else {
    let mut ok = true
    for index in 0..<self.ints.length() {
      if self.ints[index] != other.ints[index] {
        ok = false
      }
    }
    for index in 0..<self.floats.length() {
      if self.floats[index] != other.floats[index] {
        ok = false
      }
    }
    ok
  }
}

///|
fn none_block(count : Int) -> Cell {
  let series = Series::block()
  for _ in 0..<count {
    let _ = series.push_item(None)
  }
  Seq(series, 0)
}
