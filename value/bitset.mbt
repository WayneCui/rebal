///|
/// A set of characters. Codes 0 through 255 live in 32 bytes. Higher codes are listed apart.
pub struct Bitset {
  low : Array[Int]
  extra : Array[Int]
}

///|
pub fn Bitset::make() -> Bitset {
  let low : Array[Int] = []
  for _ in 0..<32 {
    low.push(0)
  }
  { low, extra: [], }
}

///|
pub fn Bitset::has(self : Bitset, code : Int) -> Bool {
  if code < 0 {
    false
  } else if code < 256 {
    let mask = bit_mask(code % 8)
    self.low[code / 8] / mask % 2 == 1
  } else {
    let mut found = false
    for extra in self.extra {
      if extra == code {
        found = true
      }
    }
    found
  }
}

///|
pub fn Bitset::insert(self : Bitset, code : Int) -> Unit {
  if code >= 0 && code < 256 {
    let index = code / 8
    let mask = bit_mask(code % 8)
    if self.low[index] / mask % 2 == 0 {
      self.low[index] = self.low[index] + mask
    }
  } else if code >= 256 && !self.has(code) {
    self.extra.push(code)
  }
}

///|
pub fn Bitset::fill(self : Bitset, start : Int, end : Int) -> Unit {
  for code in start..<=end {
    self.insert(code)
  }
}

///|
/// Flips the 256-bit plane. Codes above 255 are dropped.
pub fn Bitset::complement(self : Bitset) -> Bitset {
  let out = Bitset::make()
  for index in 0..<32 {
    out.low[index] = 255 - self.low[index]
  }
  out
}

///|
pub fn Bitset::byte(self : Bitset, index : Int) -> Int {
  self.low[index]
}

///|
pub fn Bitset::same(self : Bitset, other : Bitset) -> Bool {
  let mut ok = true
  for index in 0..<32 {
    if self.low[index] != other.low[index] {
      ok = false
    }
  }
  if self.extra.length() != other.extra.length() {
    ok = false
  }
  for code in self.extra {
    if !other.has(code) {
      ok = false
    }
  }
  ok
}

///|
fn bit_mask(bit : Int) -> Int {
  let mut mask = 1
  for _ in 0..<bit {
    mask = mask * 2
  }
  mask
}
