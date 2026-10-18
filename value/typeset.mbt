///|
/// A set of datatypes. Mold follows the Rebol catalog order.
pub struct Typeset {
  types : Array[Datatype]
}

///|
pub fn Typeset::make(types : Array[Datatype]) -> Typeset {
  { types, }
}

///|
pub fn Typeset::contains(self : Typeset, datatype : Datatype) -> Bool {
  let mut found = false
  for item in self.types {
    if item == datatype {
      found = true
    }
  }
  found
}

///|
pub fn Typeset::empty(self : Typeset) -> Bool {
  self.types.length() == 0
}

///|
pub fn Typeset::ordered(self : Typeset) -> Array[Datatype] {
  let out : Array[Datatype] = []
  for item in self.types {
    let rank = datatype_rank(item)
    let mut placed = false
    let next : Array[Datatype] = []
    for existing in out {
      if !placed && rank < datatype_rank(existing) {
        next.push(item)
        placed = true
      }
      next.push(existing)
    }
    if !placed {
      next.push(item)
    }
    out.clear()
    for existing in next {
      out.push(existing)
    }
  }
  out
}

///|
pub fn Typeset::same(self : Typeset, other : Typeset) -> Bool {
  if self.types.length() != other.types.length() {
    false
  } else {
    let mut ok = true
    for item in self.types {
      if !other.contains(item) {
        ok = false
      }
    }
    ok
  }
}

///|
/// Positions follow `system/catalog/datatypes`, restricted to types we have.
fn datatype_rank(datatype : Datatype) -> Int {
  match datatype {
    Unset => 1
    None => 2
    Logic => 3
    Integer => 4
    Decimal => 5
    Percent => 6
    Money => 7
    Char => 8
    Pair => 9
    Tuple => 10
    Time => 11
    Date => 12
    Binary => 13
    String => 14
    File => 15
    Email => 16
    Url => 17
    Tag => 18
    Bitset => 19
    Image => 20
    Vector => 21
    Block => 22
    Paren => 23
    Path => 24
    SetPath => 25
    Map => 26
    Datatype => 27
    Typeset => 28
    Word => 29
    SetWord => 30
    GetWord => 31
    LitWord => 32
    Refinement => 33
    Issue => 34
    Op => 35
    Closure => 36
    Function => 37
    Object => 38
    Module => 39
    Error => 40
    Port => 41
    Event => 42
    Handle => 43
    Struct => 44
  }
}
