///|
/// Unsigned integer in base 2^26, little-endian, with no leading zero limb.
/// A zero modulus makes `remainder` and `mod_exp` return zero.
pub struct Nat {
  limbs : Array[UInt64]
}

///|
pub fn Nat::from_bytes(bytes : Array[Int]) -> Nat {
  let limbs : Array[UInt64] = []
  let mut acc = 0UL
  let mut shift = 0
  let mut index = bytes.length() - 1
  while index >= 0 {
    acc = acc | (bytes[index].to_uint64() << shift)
    shift = shift + 8
    while shift >= 26 {
      limbs.push(acc & limb_mask())
      acc = acc >> 26
      shift = shift - 26
    }
    index = index - 1
  }
  if acc > 0 {
    limbs.push(acc)
  }
  { limbs, }
}

///|
/// Big-endian, exactly `width` bytes. A value that does not fit keeps its low bytes.
pub fn Nat::be_bytes(self : Nat, width : Int) -> Array[Int] {
  let mut limbs = copy_limbs(self.limbs)
  let low : Array[Int] = []
  let mut left = width
  while left > 0 {
    let byte = if limbs.length() == 0 { 0 } else { (limbs[0] & 255UL).to_int() }
    low.push(byte)
    limbs = shr_limbs(limbs, 8)
    left = left - 1
  }
  let out : Array[Int] = []
  let mut index = low.length() - 1
  while index >= 0 {
    out.push(low[index])
    index = index - 1
  }
  out
}

///|
pub fn Nat::remainder(self : Nat, modulus : Nat) -> Nat {
  divmod(self, modulus).1
}

///|
/// `base ** exp % modulus`, by squaring. The result is already reduced.
pub fn Nat::mod_exp(base : Nat, exp : Nat, modulus : Nat) -> Nat {
  if modulus.limbs.length() == 0 {
    zero_nat()
  } else {
    let mut result = Nat::from_bytes([1]).remainder(modulus)
    let mut factor = base.remainder(modulus)
    let mut power = { limbs: copy_limbs(exp.limbs), }
    while power.limbs.length() > 0 {
      if odd_nat(power) {
        result = product(result, factor).remainder(modulus)
      }
      power = shr_nat(power)
      if power.limbs.length() > 0 {
        factor = product(factor, factor).remainder(modulus)
      }
    }
    result
  }
}

///|
fn zero_nat() -> Nat {
  { limbs: [], }
}

///|
fn limb_mask() -> UInt64 {
  (1UL << 26) - 1
}

///|
fn limb_base() -> UInt64 {
  1UL << 26
}

///|
fn copy_limbs(limbs : Array[UInt64]) -> Array[UInt64] {
  let out : Array[UInt64] = []
  for limb in limbs {
    out.push(limb)
  }
  out
}

///|
fn trim_limbs(limbs : Array[UInt64]) -> Array[UInt64] {
  let mut end = limbs.length()
  while end > 0 && limbs[end - 1] == 0 {
    end = end - 1
  }
  let out : Array[UInt64] = []
  let mut index = 0
  while index < end {
    out.push(limbs[index])
    index = index + 1
  }
  out
}

///|
fn odd_nat(value : Nat) -> Bool {
  value.limbs.length() > 0 && (value.limbs[0] & 1UL) != 0
}

///|
fn shr_nat(value : Nat) -> Nat {
  { limbs: shr_limbs(value.limbs, 1), }
}

///|
fn product(left : Nat, right : Nat) -> Nat {
  if left.limbs.length() == 0 || right.limbs.length() == 0 {
    zero_nat()
  } else {
    let out = zero_limbs(left.limbs.length() + right.limbs.length())
    let mut i = 0
    while i < left.limbs.length() {
      let mut carry = 0UL
      let mut j = 0
      while j < right.limbs.length() {
        let slot = i + j
        let cur = out[slot] + left.limbs[i] * right.limbs[j] + carry
        out[slot] = cur & limb_mask()
        carry = cur >> 26
        j = j + 1
      }
      out[i + right.limbs.length()] = carry
      i = i + 1
    }
    { limbs: trim_limbs(out), }
  }
}

///|
fn zero_limbs(count : Int) -> Array[UInt64] {
  let out : Array[UInt64] = []
  let mut index = 0
  while index < count {
    out.push(0UL)
    index = index + 1
  }
  out
}

///|
fn shl_limbs(limbs : Array[UInt64], bits : Int) -> Array[UInt64] {
  if bits == 0 {
    copy_limbs(limbs)
  } else {
    let out : Array[UInt64] = []
    let mut carry = 0UL
    for limb in limbs {
      let cur = (limb << bits) | carry
      out.push(cur & limb_mask())
      carry = cur >> 26
    }
    if carry > 0 {
      out.push(carry)
    }
    out
  }
}

///|
fn shr_limbs(limbs : Array[UInt64], bits : Int) -> Array[UInt64] {
  if bits == 0 {
    trim_limbs(copy_limbs(limbs))
  } else {
    let out = zero_limbs(limbs.length())
    let mut carry = 0UL
    let mut index = limbs.length() - 1
    let low_mask = (1UL << bits) - 1
    while index >= 0 {
      let cur = limbs[index]
      out[index] = ((cur >> bits) | carry) & limb_mask()
      carry = (cur & low_mask) << (26 - bits)
      index = index - 1
    }
    trim_limbs(out)
  }
}

///|
fn norm_shift(limb : UInt64) -> Int {
  let mut shift = 0
  let mut value = limb
  while value < 1UL << 25 && shift < 26 {
    value = value << 1
    shift = shift + 1
  }
  shift
}

///|
fn divmod(dividend : Nat, divisor : Nat) -> (Nat, Nat) {
  if divisor.limbs.length() == 0 {
    (zero_nat(), zero_nat())
  } else if dividend.limbs.length() == 0 {
    (zero_nat(), zero_nat())
  } else {
    let shift = norm_shift(divisor.limbs[divisor.limbs.length() - 1])
    let left = shl_limbs(dividend.limbs, shift)
    let right = shl_limbs(divisor.limbs, shift)
    if left.length() < right.length() {
      (zero_nat(), { limbs: shr_limbs(left, shift), })
    } else {
      left.push(0UL)
      let n = right.length()
      let m = left.length() - n - 1
      let quot = zero_limbs(m + 1)
      let mut j = m
      while j >= 0 {
        let guess = quotient_digit(left, right, j)
        if sub_product(left, right, guess, j) {
          add_divisor(left, right, j)
          quot[j] = guess - 1
        } else {
          quot[j] = guess
        }
        j = j - 1
      }
      let rest : Array[UInt64] = []
      let mut index = 0
      while index < n {
        rest.push(left[index])
        index = index + 1
      }
      ({ limbs: trim_limbs(quot), }, { limbs: shr_limbs(rest, shift), })
    }
  }
}

///|
fn quotient_digit(
  left : Array[UInt64],
  right : Array[UInt64],
  j : Int,
) -> UInt64 {
  let n = right.length()
  let den = right[n - 1]
  let num = left[j + n] * limb_base() + left[j + n - 1]
  let mut qhat = num / den
  let mut rhat = num % den
  let lower = if n > 1 { right[n - 2] } else { 0UL }
  let u0 = if n > 1 { left[j + n - 2] } else { 0UL }
  while digit_too_big(qhat, rhat, lower, u0) {
    qhat = qhat - 1
    rhat = rhat + den
    if rhat >= limb_base() {
      break
    }
  }
  qhat
}

///|
fn digit_too_big(
  qhat : UInt64,
  rhat : UInt64,
  lower : UInt64,
  u0 : UInt64,
) -> Bool {
  if qhat >= limb_base() {
    true
  } else {
    qhat * lower > rhat * limb_base() + u0
  }
}

///|
fn sub_product(
  left : Array[UInt64],
  right : Array[UInt64],
  qhat : UInt64,
  j : Int,
) -> Bool {
  let mut carry = 0UL
  let mut borrow = 0UL
  let mut i = 0
  while i < right.length() {
    let prod = right[i] * qhat + carry
    carry = prod >> 26
    let need = (prod & limb_mask()) + borrow
    let cur = left[j + i]
    if cur >= need {
      left[j + i] = cur - need
      borrow = 0UL
    } else {
      left[j + i] = cur + limb_base() - need
      borrow = 1UL
    }
    i = i + 1
  }
  let extra = carry + borrow
  let top = j + right.length()
  if left[top] >= extra {
    left[top] = left[top] - extra
    false
  } else {
    left[top] = left[top] + limb_base() - extra
    true
  }
}

///|
fn add_divisor(left : Array[UInt64], right : Array[UInt64], j : Int) -> Unit {
  let mut carry = 0UL
  let mut i = 0
  while i < right.length() {
    let sum = left[j + i] + right[i] + carry
    left[j + i] = sum & limb_mask()
    carry = sum >> 26
    i = i + 1
  }
  let mut k = right.length()
  while carry > 0 {
    let sum = left[j + k] + carry
    left[j + k] = sum & limb_mask()
    carry = sum >> 26
    k = k + 1
  }
}
