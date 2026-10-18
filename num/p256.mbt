///|
/// Scalar times the P-256 base point. The scalar is big-endian and must lie
/// in `1 .. n-1`. Coordinates come back as 32-byte big-endian integers.
pub fn p256_base_mul(scalar : Array[Int]) -> (Array[Int], Array[Int])? {
  let (gx, gy) = p256_g()
  p256_mul(scalar, gx, gy)
}

///|
/// Scalar times an affine point. The point must lie on the curve.
pub fn p256_mul(
  scalar : Array[Int],
  x : Array[Int],
  y : Array[Int],
) -> (Array[Int], Array[Int])? {
  if !p256_scalar_ok(scalar) || !p256_on_curve(x, y) {
    None
  } else {
    let point = jac_mul(scalar, fe_norm(x), fe_norm(y))
    match jac_affine(point) {
      None => None
      Some((ax, ay)) => Some((ax.be_bytes(32), ay.be_bytes(32)))
    }
  }
}

///|
pub fn p256_on_curve(x : Array[Int], y : Array[Int]) -> Bool {
  let prime = p256_p()
  let raw_x = Nat::from_bytes(x)
  let raw_y = Nat::from_bytes(y)
  if nat_cmp(raw_x, prime) >= 0 || nat_cmp(raw_y, prime) >= 0 {
    false
  } else {
    let xx = raw_x.remainder(prime)
    let yy = raw_y.remainder(prime)
    let left = fe_sqr(yy)
    let right = fe_add(fe_mul(xx, fe_sub(fe_sqr(xx), small(3))), p256_b())
    nat_cmp(left, right) == 0
  }
}

///|
priv struct Jac {
  x : Nat
  y : Nat
  z : Nat
  inf : Bool
}

///|
fn jac_inf() -> Jac {
  { x: small(0), y: small(0), z: small(0), inf: true, }
}

///|
fn jac_mul(scalar : Array[Int], x : Nat, y : Nat) -> Jac {
  let mut acc = jac_inf()
  let mut index = 0
  while index < scalar.length() && scalar[index] == 0 {
    index = index + 1
  }
  while index < scalar.length() {
    let byte = scalar[index]
    let mut mask = 128
    while mask > 0 {
      if !acc.inf {
        acc = jac_dbl(acc)
      }
      if (byte & mask) != 0 {
        acc = jac_add(acc, x, y)
      }
      mask = mask / 2
    }
    index = index + 1
  }
  acc
}

///|
fn jac_dbl(point : Jac) -> Jac {
  if point.inf || nat_zero(point.y) {
    jac_inf()
  } else {
    let delta = fe_sqr(point.z)
    let gamma = fe_sqr(point.y)
    let beta = fe_mul(point.x, gamma)
    let alpha = fe_mul(
      small(3),
      fe_mul(fe_sub(point.x, delta), fe_add(point.x, delta)),
    )
    let x3 = fe_sub(fe_sqr(alpha), fe_mul(small(8), beta))
    let z3 = fe_sub(fe_sub(fe_sqr(fe_add(point.y, point.z)), gamma), delta)
    let y3 = fe_sub(
      fe_mul(alpha, fe_sub(fe_mul(small(4), beta), x3)),
      fe_mul(small(8), fe_sqr(gamma)),
    )
    { x: x3, y: y3, z: z3, inf: false, }
  }
}

///|
fn jac_add(point : Jac, x : Nat, y : Nat) -> Jac {
  if point.inf {
    { x, y, z: small(1), inf: false, }
  } else {
    let z1z1 = fe_sqr(point.z)
    let u2 = fe_mul(x, z1z1)
    let s2 = fe_mul(y, fe_mul(point.z, z1z1))
    let h = fe_sub(u2, point.x)
    if nat_zero(h) {
      if nat_cmp(s2, point.y) == 0 {
        jac_dbl(point)
      } else {
        jac_inf()
      }
    } else {
      jac_add_h(point, z1z1, h, s2)
    }
  }
}

///|
fn jac_add_h(point : Jac, z1z1 : Nat, h : Nat, s2 : Nat) -> Jac {
  let hh = fe_sqr(h)
  let i = fe_mul(small(4), hh)
  let j = fe_mul(h, i)
  let r = fe_mul(small(2), fe_sub(s2, point.y))
  let v = fe_mul(point.x, i)
  let x3 = fe_sub(fe_sub(fe_sqr(r), j), fe_mul(small(2), v))
  let y3 = fe_sub(
    fe_mul(r, fe_sub(v, x3)),
    fe_mul(small(2), fe_mul(point.y, j)),
  )
  let z3 = fe_sub(fe_sub(fe_sqr(fe_add(point.z, h)), z1z1), hh)
  { x: x3, y: y3, z: z3, inf: false, }
}

///|
fn jac_affine(point : Jac) -> (Nat, Nat)? {
  if point.inf || nat_zero(point.z) {
    None
  } else {
    let inv = Nat::mod_exp(point.z, nat_sub(p256_p(), small(2)), p256_p())
    let inv2 = fe_sqr(inv)
    Some((fe_mul(point.x, inv2), fe_mul(point.y, fe_mul(inv2, inv))))
  }
}

///|
fn p256_scalar_ok(scalar : Array[Int]) -> Bool {
  let value = Nat::from_bytes(scalar)
  !nat_zero(value) && nat_cmp(value, p256_n()) < 0
}

///|
fn fe_norm(bytes : Array[Int]) -> Nat {
  Nat::from_bytes(bytes).remainder(p256_p())
}

///|
fn fe_add(left : Nat, right : Nat) -> Nat {
  nat_add(left, right).remainder(p256_p())
}

///|
fn fe_sub(left : Nat, right : Nat) -> Nat {
  if nat_cmp(left, right) >= 0 {
    nat_sub(left, right)
  } else {
    nat_sub(nat_add(left, p256_p()), right)
  }
}

///|
fn fe_mul(left : Nat, right : Nat) -> Nat {
  product(left, right).remainder(p256_p())
}

///|
fn fe_sqr(value : Nat) -> Nat {
  fe_mul(value, value)
}

///|
fn small(value : Int) -> Nat {
  Nat::from_bytes([value])
}

///|
fn nat_zero(value : Nat) -> Bool {
  value.limbs.length() == 0
}

///|
fn nat_cmp(left : Nat, right : Nat) -> Int {
  if left.limbs.length() != right.limbs.length() {
    if left.limbs.length() < right.limbs.length() {
      -1
    } else {
      1
    }
  } else {
    let mut index = left.limbs.length() - 1
    let mut order = 0
    while index >= 0 && order == 0 {
      if left.limbs[index] < right.limbs[index] {
        order = -1
      } else if left.limbs[index] > right.limbs[index] {
        order = 1
      }
      index = index - 1
    }
    order
  }
}

///|
fn nat_add(left : Nat, right : Nat) -> Nat {
  let out : Array[UInt64] = []
  let mut carry = 0UL
  let mut index = 0
  let limit = if left.limbs.length() > right.limbs.length() {
    left.limbs.length()
  } else {
    right.limbs.length()
  }
  while index < limit || carry > 0 {
    let a = if index < left.limbs.length() { left.limbs[index] } else { 0UL }
    let b = if index < right.limbs.length() { right.limbs[index] } else { 0UL }
    let cur = a + b + carry
    out.push(cur & limb_mask())
    carry = cur >> 26
    index = index + 1
  }
  { limbs: trim_limbs(out), }
}

///|
fn nat_sub(left : Nat, right : Nat) -> Nat {
  let out : Array[UInt64] = []
  let mut borrow = 0UL
  let mut index = 0
  while index < left.limbs.length() {
    let b = if index < right.limbs.length() { right.limbs[index] } else { 0UL }
    let a = left.limbs[index]
    if a >= b + borrow {
      out.push(a - b - borrow)
      borrow = 0UL
    } else {
      out.push(a + limb_base() - b - borrow)
      borrow = 1UL
    }
    index = index + 1
  }
  { limbs: trim_limbs(out), }
}

///|
fn p256_p() -> Nat {
  hex_nat("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF")
}

///|
fn p256_n() -> Nat {
  hex_nat("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551")
}

///|
fn p256_b() -> Nat {
  hex_nat("5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B")
}

///|
fn p256_g() -> (Array[Int], Array[Int]) {
  (
    hex_digits(
      "6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296",
    ),
    hex_digits(
      "4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5",
    ),
  )
}

///|
fn hex_nat(text : String) -> Nat {
  Nat::from_bytes(hex_digits(text))
}

///|
fn hex_digits(text : String) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  while index + 1 < text.length() {
    out.push(
      hex_val(text[index].to_int()) * 16 + hex_val(text[index + 1].to_int()),
    )
    index = index + 2
  }
  out
}

///|
fn hex_val(code : Int) -> Int {
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 97 && code <= 102 {
    code - 87
  } else {
    code - 55
  }
}
