///|
/// Depth limit so a cyclic block cannot loop forever. Past this, values compare unequal.
let max_equal_depth : Int = 32

///|
pub fn Cell::equal(self : Cell, other : Cell) -> Bool {
  equal_at(self, other, 0)
}

///|
fn equal_at(left : Cell, right : Cell, depth : Int) -> Bool {
  if depth > max_equal_depth {
    false
  } else {
    match (left, right) {
      (Unset, Unset) => true
      (None, None) => true
      (Logic(a), Logic(b)) => a == b
      (Integer(a), Integer(b)) => a == b
      (Decimal(a), Decimal(b)) => a == b
      (Percent(a), Percent(b)) => a == b
      (Pair(a, b), Pair(c, d)) => a == c && b == d
      (Tuple(a), Tuple(b)) => tuple_same(a, b)
      (Money(a), Money(b)) => a == b
      (Time(a), Time(b)) => a == b
      (Date(a), Date(b)) => a.same(b)
      (Char(a), Char(b)) => a == b
      (Sym(_, a), Sym(_, b)) => a.sym == b.sym
      (Seq(a, ai), Seq(b, bi)) =>
        a.datatype() == b.datatype() && series_equal(a, ai, b, bi, depth + 1)
      (Type(a), Type(b)) => a == b
      (Function(a), Function(b)) => physical_equal(a, b)
      (Object(a), Object(b)) => physical_equal(a, b)
      (Error(a), Error(b)) =>
        a.id == b.id && a.arg1 == b.arg1 && a.near == b.near
      _ => false
    }
  }
}

///|
fn series_equal(
  left : Series,
  left_index : Int,
  right : Series,
  right_index : Int,
  depth : Int,
) -> Bool {
  let left_len = left.length() - left_index
  let right_len = right.length() - right_index
  if left_len != right_len {
    false
  } else {
    match (left.payload, right.payload) {
      (Items(xs), Items(ys)) => {
        let mut ok = true
        for i in 0..<left_len {
          if ok && !equal_at(xs[left_index + i], ys[right_index + i], depth) {
            ok = false
          }
        }
        ok
      }
      (Text(xs), Text(ys)) => {
        let mut ok = true
        for i in 0..<left_len {
          if ok && xs[left_index + i] != ys[right_index + i] {
            ok = false
          }
        }
        ok
      }
      (Bytes(xs), Bytes(ys)) => {
        let mut ok = true
        for i in 0..<left_len {
          if ok && xs[left_index + i] != ys[right_index + i] {
            ok = false
          }
        }
        ok
      }
      _ => false
    }
  }
}

///|
fn tuple_same(left : Array[Int], right : Array[Int]) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    let mut ok = true
    for i in 0..<left.length() {
      if left[i] != right[i] {
        ok = false
      }
    }
    ok
  }
}

///|
/// Series identity, ignoring the index. Other cells are not the same.
pub fn Cell::same(self : Cell, other : Cell) -> Bool {
  match (self, other) {
    (Seq(a, _), Seq(b, _)) => physical_equal(a, b)
    _ => false
  }
}
