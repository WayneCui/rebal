///|
fn to_percent(spec : @value.Cell, making : Bool) -> @value.Cell raise EvalError {
  match spec {
    @value.Integer(n) => @value.Percent(n.to_double())
    @value.Decimal(n) => @value.Percent(n)
    @value.Percent(n) => @value.Percent(n)
    @value.Logic(true) if making => @value.Percent(1.0)
    @value.Logic(false) if making => @value.Percent(0.0)
    _ => raise EvalError::Cannot(if making { "make" } else { "to" })
  }
}

///|
fn decimal_from(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Percent(n) => @value.Decimal(n)
    @value.Decimal(n) => @value.Decimal(n)
    @value.Integer(n) => @value.Decimal(n.to_double())
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn integer_from(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Percent(n) => @value.Integer(n.to_int64())
    @value.Integer(n) => @value.Integer(n)
    @value.Decimal(n) => @value.Integer(n.to_int64())
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn perform_to(
  datatype : @value.Cell,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  match datatype {
    @value.Type(@value.Percent) => to_percent(spec, false)
    @value.Type(@value.Decimal) => decimal_from(spec)
    @value.Type(@value.Integer) => integer_from(spec)
    _ => raise EvalError::Cannot("to")
  }
}
