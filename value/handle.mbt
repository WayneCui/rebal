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

///|
/// RC4 stream state. Copies share it, so `rc4/stream` advances every alias.
pub struct Rc4Key {
  priv s : Array[Int]
  priv ij : Array[Int]
  priv closed : Array[Int]
}

///|
pub fn Rc4Key::setup(key : Array[Int]) -> Rc4Key? {
  if key.length() == 0 {
    None
  } else {
    let s : Array[Int] = []
    let mut i = 0
    while i < 256 {
      s.push(i)
      i = i + 1
    }
    let mut j = 0
    let mut k = 0
    i = 0
    while i < 256 {
      let a = s[i]
      j = (j + a + key[k]) & 0xFF
      s[i] = s[j]
      s[j] = a
      k = k + 1
      if k >= key.length() {
        k = 0
      }
      i = i + 1
    }
    Some({ s, ij: [0, 0], closed: [0], })
  }
}

///|
/// XOR `data` with the next keystream bytes and advance the stream.
pub fn Rc4Key::xor(self : Rc4Key, data : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  let mut x = self.ij[0]
  let mut y = self.ij[1]
  for byte in data {
    x = (x + 1) & 0xFF
    let a = self.s[x]
    y = (y + a) & 0xFF
    let b = self.s[y]
    self.s[x] = b
    self.s[y] = a
    out.push(byte ^ self.s[(a + b) & 0xFF])
  }
  self.ij[0] = x
  self.ij[1] = y
  out
}

///|
pub fn Rc4Key::same(self : Rc4Key, other : Rc4Key) -> Bool {
  same_bytes(self.s, other.s) && same_bytes(self.ij, other.ij)
}

///|
pub fn Rc4Key::release(self : Rc4Key) -> Unit {
  self.closed[0] = 1
}

///|
pub fn Rc4Key::released(self : Rc4Key) -> Bool {
  self.closed[0] != 0
}

///|
pub(all) enum HandleValue {
  Rsa(RsaKey)
  Dhm(DhKey)
  Rc4(Rc4Key)
}

///|
pub fn HandleValue::same(self : HandleValue, other : HandleValue) -> Bool {
  match (self, other) {
    (Rsa(a), Rsa(b)) => a.same(b)
    (Dhm(a), Dhm(b)) => a.same(b)
    (Rc4(a), Rc4(b)) => a.same(b)
    _ => false
  }
}

///|
pub fn HandleValue::kind(self : HandleValue) -> String {
  match self {
    Rsa(_) => "rsa"
    Dhm(_) => "dhm"
    Rc4(_) => "rc4"
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
    Rc4(key) => key.release()
  }
}

///|
pub fn HandleValue::released(self : HandleValue) -> Bool {
  match self {
    Rsa(key) => key.released()
    Dhm(key) => key.released()
    Rc4(key) => key.released()
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
