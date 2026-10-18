///|
/// RSA public numbers. The modulus is at least 128 bits, and the exponent
/// is an odd integer of at least two bits, smaller than the modulus.
pub struct RsaKey {
  n : Array[Int]
  e : Array[Int]
  d : Array[Int]
  p : Array[Int]
  q : Array[Int]
  priv closed : Array[Int]
}

///|
pub fn RsaKey::new(n : Array[Int], e : Array[Int]) -> RsaKey? {
  if public_ok(n, e) {
    Some({ n, e, d: [], p: [], q: [], closed: [0], })
  } else {
    None
  }
}

///|
/// PKCS#1 private numbers. `d`, `p`, and `q` are kept with the public pair.
pub fn RsaKey::from_private(
  n : Array[Int],
  e : Array[Int],
  d : Array[Int],
  p : Array[Int],
  q : Array[Int],
) -> RsaKey? {
  if public_ok(n, e) &&
    magnitude_bits(d) >= 2 &&
    magnitude_bits(p) >= 2 &&
    magnitude_bits(q) >= 2 {
    Some({ n, e, d, p, q, closed: [0], })
  } else {
    None
  }
}

///|
/// Diffie-Hellman parameters. The prime is at least 128 bits, and the
/// generator is a smaller positive integer.
pub struct DhKey {
  p : Array[Int]
  g : Array[Int]
  priv closed : Array[Int]
}

///|
pub fn DhKey::new(p : Array[Int], g : Array[Int]) -> DhKey? {
  if magnitude_bits(p) >= 128 && magnitude_bits(g) >= 1 && less_magnitude(g, p) {
    Some({ p, g, closed: [0], })
  } else {
    None
  }
}

///|
pub fn DhKey::same(self : DhKey, other : DhKey) -> Bool {
  same_bytes(self.p, other.p) && same_bytes(self.g, other.g)
}

///|
pub(all) enum HandleValue {
  Rsa(RsaKey)
  Dhm(DhKey)
}

///|
pub fn HandleValue::same(self : HandleValue, other : HandleValue) -> Bool {
  match (self, other) {
    (Rsa(a), Rsa(b)) => a.same(b)
    (Dhm(a), Dhm(b)) => a.same(b)
    _ => false
  }
}

///|
pub fn HandleValue::kind(self : HandleValue) -> String {
  match self {
    Rsa(_) => "rsa"
    Dhm(_) => "dhm"
  }
}

///|
pub fn RsaKey::release(self : RsaKey) -> Unit {
  self.closed[0] = 1
}

///|
pub fn RsaKey::released(self : RsaKey) -> Bool {
  self.closed[0] != 0
}

///|
pub fn DhKey::release(self : DhKey) -> Unit {
  self.closed[0] = 1
}

///|
pub fn DhKey::released(self : DhKey) -> Bool {
  self.closed[0] != 0
}

///|
pub fn HandleValue::release(self : HandleValue) -> Unit {
  match self {
    Rsa(key) => key.release()
    Dhm(key) => key.release()
  }
}

///|
pub fn HandleValue::released(self : HandleValue) -> Bool {
  match self {
    Rsa(key) => key.released()
    Dhm(key) => key.released()
  }
}

///|
pub fn RsaKey::same(self : RsaKey, other : RsaKey) -> Bool {
  same_bytes(self.n, other.n) &&
  same_bytes(self.e, other.e) &&
  same_bytes(self.d, other.d) &&
  same_bytes(self.p, other.p) &&
  same_bytes(self.q, other.q)
}

///|
fn public_ok(n : Array[Int], e : Array[Int]) -> Bool {
  magnitude_bits(n) >= 128 &&
  magnitude_bits(e) >= 2 &&
  odd_magnitude(e) &&
  less_magnitude(e, n)
}

///|
fn magnitude_bits(bytes : Array[Int]) -> Int {
  let mut index = 0
  while index < bytes.length() && bytes[index] == 0 {
    index = index + 1
  }
  if index == bytes.length() {
    0
  } else {
    let mut top = bytes[index]
    let mut bits = 0
    while top > 0 {
      bits = bits + 1
      top = top / 2
    }
    bits + (bytes.length() - index - 1) * 8
  }
}

///|
fn odd_magnitude(bytes : Array[Int]) -> Bool {
  let mut index = bytes.length() - 1
  while index > 0 && bytes[index] == 0 {
    index = index - 1
  }
  if index < 0 {
    false
  } else {
    (bytes[index] & 1) == 1
  }
}

///|
fn less_magnitude(left : Array[Int], right : Array[Int]) -> Bool {
  let a = strip_zeros(left)
  let b = strip_zeros(right)
  if a.length() != b.length() {
    a.length() < b.length()
  } else {
    let mut index = 0
    let mut less = false
    let mut done = false
    while !done && index < a.length() {
      if a[index] != b[index] {
        less = a[index] < b[index]
        done = true
      }
      index = index + 1
    }
    less
  }
}

///|
fn strip_zeros(bytes : Array[Int]) -> Array[Int] {
  let mut index = 0
  while index < bytes.length() && bytes[index] == 0 {
    index = index + 1
  }
  let out : Array[Int] = []
  while index < bytes.length() {
    out.push(bytes[index])
    index = index + 1
  }
  out
}

///|
fn same_bytes(left : Array[Int], right : Array[Int]) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    let mut index = 0
    let mut same = true
    while same && index < left.length() {
      if left[index] != right[index] {
        same = false
      }
      index = index + 1
    }
    same
  }
}
