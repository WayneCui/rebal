///|
/// An event keeps a type name, an optional pair, an optional code, and a port.
/// The arrays are the mutable slots. An empty array means that slot is unset.
pub struct EventValue {
  names : Array[String]
  xy : Array[Int]
  codes : Array[Int]
  ports : Array[Cell]
}

///|
pub fn EventValue::blank() -> EventValue {
  { names: [], xy: [], codes: [], ports: [], }
}

///|
pub fn EventValue::copy(self : EventValue) -> EventValue {
  let names : Array[String] = []
  let xy : Array[Int] = []
  let codes : Array[Int] = []
  let ports : Array[Cell] = []
  for name in self.names {
    names.push(name)
  }
  for value in self.xy {
    xy.push(value)
  }
  for value in self.codes {
    codes.push(value)
  }
  for port in self.ports {
    ports.push(port)
  }
  { names, xy, codes, ports, }
}

///|
pub fn EventValue::set_kind(self : EventValue, kind : String) -> Unit {
  clear_strings(self.names)
  self.names.push(kind)
}

///|
pub fn EventValue::set_offset(self : EventValue, x : Int, y : Int) -> Unit {
  clear_ints(self.xy)
  self.xy.push(x)
  self.xy.push(y)
  clear_ints(self.codes)
}

///|
pub fn EventValue::set_code(self : EventValue, code : Int) -> Unit {
  clear_ints(self.codes)
  self.codes.push(code)
  clear_ints(self.xy)
}

///|
pub fn EventValue::set_port(self : EventValue, port : Cell) -> Unit {
  clear_cells(self.ports)
  match port {
    None => ()
    _ => self.ports.push(port)
  }
}

///|
pub fn EventValue::kind(self : EventValue) -> String {
  if self.names.length() == 0 {
    ""
  } else {
    self.names[0]
  }
}

///|
pub fn EventValue::offset(self : EventValue) -> (Int, Int)? {
  if self.xy.length() == 2 {
    Some((self.xy[0], self.xy[1]))
  } else {
    None
  }
}

///|
pub fn EventValue::code(self : EventValue) -> Int? {
  if self.codes.length() == 0 {
    None
  } else {
    Some(self.codes[0])
  }
}

///|
pub fn EventValue::port(self : EventValue) -> Cell {
  if self.ports.length() == 0 {
    None
  } else {
    self.ports[0]
  }
}

///|
pub fn EventValue::shows_key(self : EventValue) -> Bool {
  self.codes.length() > 0 && (self.kind() == "key" || self.kind() == "key-up")
}

///|
pub fn EventValue::same(self : EventValue, other : EventValue) -> Bool {
  self.kind() == other.kind() &&
  same_ints(self.xy, other.xy) &&
  same_ints(self.codes, other.codes) &&
  self.port().equal(other.port())
}

///|
fn clear_strings(values : Array[String]) -> Unit {
  while values.length() > 0 {
    values.pop() |> ignore
  }
}

///|
fn clear_ints(values : Array[Int]) -> Unit {
  while values.length() > 0 {
    values.pop() |> ignore
  }
}

///|
fn clear_cells(values : Array[Cell]) -> Unit {
  while values.length() > 0 {
    values.pop() |> ignore
  }
}

///|
fn same_ints(left : Array[Int], right : Array[Int]) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    let mut ok = true
    for index in 0..<left.length() {
      if left[index] != right[index] {
        ok = false
      }
    }
    ok
  }
}
