///|
/// `and`, `or`, and `xor` keep r3's dispatch: an integer pair is bitwise,
/// any other pair goes to the logic action, which reports the type error.
fn bitwise_or_logic(
  left : @value.Cell,
  right : @value.Cell,
  bits : (Int64, Int64) -> Int64,
  fallback : (@value.Cell, @value.Cell) -> @value.Cell raise EvalError,
) -> @value.Cell raise EvalError {
  match (left, right) {
    (@value.Integer(a), @value.Integer(b)) => @value.Integer(bits(a, b))
    _ => fallback(left, right)
  }
}

///|
fn perform_logic_xor(
  left : @value.Cell,
  right : @value.Cell,
) -> @value.Cell raise EvalError {
  match (left, right) {
    (@value.Logic(a), @value.Logic(b)) => @value.Logic(a != b)
    _ => raise EvalError::Cannot("xor")
  }
}

///|
/// r3's `mod`: the remainder of division floored toward minus infinity, so
/// the sign follows the divisor. `7 mod 4` is 3 and `-7 mod 4` is 1.
fn floored_mod(left : @value.Cell, right : @value.Cell) -> @value.Cell raise EvalError {
  match (left, right) {
    (@value.Integer(a), @value.Integer(b)) =>
      if b == 0L {
        raise EvalError::Cannot("zero-divide")
      } else {
        let r = a % b
        @value.Integer(if r != 0L && (r < 0L) != (b < 0L) { r + b } else { r })
      }
    (@value.Decimal(a), @value.Decimal(b)) =>
      if b == 0.0 {
        raise EvalError::Cannot("zero-divide")
      } else {
        @value.Decimal(a - b * (a / b).floor())
      }
    (@value.Integer(a), @value.Decimal(b)) =>
      if b == 0.0 {
        raise EvalError::Cannot("zero-divide")
      } else {
        @value.Decimal(a.to_double() - b * (a.to_double() / b).floor())
      }
    (@value.Decimal(a), @value.Integer(b)) =>
      if b == 0L {
        raise EvalError::Cannot("zero-divide")
      } else {
        let divisor = b.to_double()
        @value.Decimal(a - divisor * (a / divisor).floor())
      }
    _ => raise EvalError::Cannot("mod")
  }
}
