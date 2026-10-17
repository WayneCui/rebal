///|
enum Payload {
  Items(Array[Cell])
  Text(Array[Int])
  Bytes(Array[Byte])
}

///|
/// Shared buffer. The position lives on the cell, not here.
pub struct Series {
  datatype : Datatype
  payload : Payload
}

///|
pub fn Series::block() -> Series {
  Series::make(Block, Items([]))
}

///|
pub fn Series::paren() -> Series {
  Series::make(Paren, Items([]))
}

///|
pub fn Series::path() -> Series {
  Series::make(Path, Items([]))
}

///|
pub fn Series::set_path() -> Series {
  Series::make(SetPath, Items([]))
}

///|
pub fn Series::text() -> Series {
  Series::make(String, Text([]))
}

///|
pub fn Series::text_of(datatype : Datatype) -> Series {
  Series::make(datatype, Text([]))
}

///|
pub fn Series::binary() -> Series {
  Series::make(Binary, Bytes([]))
}

///|
fn Series::make(datatype : Datatype, payload : Payload) -> Series {
  { datatype, payload, }
}

///|
pub fn Series::datatype(self : Series) -> Datatype {
  self.datatype
}

///|
pub fn Series::length(self : Series) -> Int {
  match self.payload {
    Items(xs) => xs.length()
    Text(xs) => xs.length()
    Bytes(xs) => xs.length()
  }
}

///|
pub fn Series::item(self : Series, index : Int) -> Cell? {
  match self.payload {
    Items(xs) => xs.get(index)
    Text(_) | Bytes(_) => None
  }
}

///|
pub fn Series::set_item(self : Series, index : Int, cell : Cell) -> Bool {
  match self.payload {
    Items(xs) =>
      match xs.get(index) {
        Some(_) => {
          xs[index] = cell
          true
        }
        None => false
      }
    Text(_) | Bytes(_) => false
  }
}

///|
pub fn Series::insert_item(self : Series, index : Int, cell : Cell) -> Bool {
  match self.payload {
    Items(xs) =>
      if index >= 0 && index <= xs.length() {
        xs.insert(index, cell)
        true
      } else {
        false
      }
    Text(_) | Bytes(_) => false
  }
}

///|
pub fn Series::remove_item(self : Series, index : Int) -> Cell? {
  match self.payload {
    Items(xs) =>
      if index >= 0 && index < xs.length() {
        Some(xs.remove(index))
      } else {
        None
      }
    Text(_) | Bytes(_) => None
  }
}

///|
pub fn Series::push_item(self : Series, cell : Cell) -> Bool {
  match self.payload {
    Items(xs) => {
      xs.push(cell)
      true
    }
    Text(_) | Bytes(_) => false
  }
}

///|
pub fn Series::set_code(self : Series, index : Int, code : Int) -> Bool {
  match self.payload {
    Text(xs) =>
      match xs.get(index) {
        Some(_) => {
          xs[index] = code
          true
        }
        None => false
      }
    Items(_) | Bytes(_) => false
  }
}

///|
pub fn Series::code(self : Series, index : Int) -> Int? {
  match self.payload {
    Text(xs) => xs.get(index)
    Items(_) | Bytes(_) => None
  }
}

///|
pub fn Series::insert_code(self : Series, index : Int, code : Int) -> Bool {
  match self.payload {
    Text(xs) =>
      if index >= 0 && index <= xs.length() {
        xs.insert(index, code)
        true
      } else {
        false
      }
    Items(_) | Bytes(_) => false
  }
}

///|
pub fn Series::remove_code(self : Series, index : Int) -> Int? {
  match self.payload {
    Text(xs) =>
      if index >= 0 && index < xs.length() {
        Some(xs.remove(index))
      } else {
        None
      }
    Items(_) | Bytes(_) => None
  }
}

///|
pub fn Series::push_code(self : Series, code : Int) -> Bool {
  match self.payload {
    Text(xs) => {
      xs.push(code)
      true
    }
    Items(_) | Bytes(_) => false
  }
}

///|
pub fn Series::byte_at(self : Series, index : Int) -> Byte? {
  match self.payload {
    Bytes(xs) => xs.get(index)
    Items(_) | Text(_) => None
  }
}

///|
pub fn Series::insert_byte(self : Series, index : Int, byte : Byte) -> Bool {
  match self.payload {
    Bytes(xs) =>
      if index >= 0 && index <= xs.length() {
        xs.insert(index, byte)
        true
      } else {
        false
      }
    Items(_) | Text(_) => false
  }
}

///|
pub fn Series::remove_byte(self : Series, index : Int) -> Byte? {
  match self.payload {
    Bytes(xs) =>
      if index >= 0 && index < xs.length() {
        Some(xs.remove(index))
      } else {
        None
      }
    Items(_) | Text(_) => None
  }
}

///|
pub fn Series::push_byte(self : Series, byte : Byte) -> Bool {
  match self.payload {
    Bytes(xs) => {
      xs.push(byte)
      true
    }
    Items(_) | Text(_) => false
  }
}

///|
/// Shallow copy of the tail starting at `index`. Word cells are snapshotted so
/// a later rebind of the source does not change the copy. Nested series stay shared.
pub fn Series::copy_from(self : Series, index : Int) -> Series {
  let start = if index < 0 { 0 } else { index }
  match self.payload {
    Items(xs) => {
      let out = Series::make(self.datatype, Items([]))
      for i in start..<xs.length() {
        out.push_item(xs[i].snapshot()) |> ignore
      }
      out
    }
    Text(xs) => {
      let out = Series::text()
      for i in start..<xs.length() {
        out.push_code(xs[i]) |> ignore
      }
      out
    }
    Bytes(xs) => {
      let out = Series::binary()
      for i in start..<xs.length() {
        out.push_byte(xs[i]) |> ignore
      }
      out
    }
  }
}
