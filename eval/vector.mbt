///|
/// `make vector!`. A block of integers is `int64!`. A decimal makes it
/// `float64!`. `make vector! 3` is three `int32!` zeros. `uint8! 256` wraps.
fn make_vector(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Integer(count) =>
      if count < 0L {
        raise EvalError::Caused("bad-make-arg", "vector!")
      } else {
        let ints : Array[Int64] = []
        let mut index = 0L
        while index < count {
          ints.push(0L)
          index = index + 1L
        }
        @value.Vector(@value.Vector::ints(@value.VectorKind::Int32, ints))
      }
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      vector_block(series, index)
    _ => raise EvalError::Caused("bad-make-arg", "vector!")
  }
}

///|
fn vector_block(
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let items : Array[@value.Cell] = []
  for cursor in index..<series.length() {
    match series.item(cursor) {
      Some(item) => items.push(item)
      None => ()
    }
  }
  if items.length() == 0 {
    raise EvalError::Caused("bad-make-arg", "vector!")
  }
  match items[0] {
    @value.Sym(_, lexeme) => vector_typed(items, lexeme.spelling().to_lower())
    _ => vector_inferred(items)
  }
}

///|
fn vector_typed(
  items : Array[@value.Cell],
  name : String,
) -> @value.Cell raise EvalError {
  if name == "unsigned" {
    if items.length() >= 4 && vector_word(items[1], "integer!") {
      match items[2] {
        @value.Integer(bits) =>
          vector_ints(unsigned_kind(bits), vector_tail(items, 3))
        _ => raise EvalError::Caused("bad-make-arg", "vector!")
      }
    } else {
      raise EvalError::Caused("bad-make-arg", "vector!")
    }
  } else if name == "integer!" {
    match items[1] {
      @value.Integer(bits) =>
        vector_ints(signed_kind(bits), vector_tail(items, 2))
      _ => raise EvalError::Caused("bad-make-arg", "vector!")
    }
  } else if name == "decimal!" {
    match items[1] {
      @value.Integer(bits) =>
        vector_floats(float_kind(bits), vector_tail(items, 2))
      _ => raise EvalError::Caused("bad-make-arg", "vector!")
    }
  } else {
    match named_kind(name) {
      Some(kind) =>
        if kind.float() {
          vector_floats(kind, vector_tail(items, 1))
        } else {
          vector_ints(kind, vector_tail(items, 1))
        }
      None => raise EvalError::Caused("bad-make-arg", "vector!")
    }
  }
}

///|
fn vector_tail(
  items : Array[@value.Cell],
  at : Int,
) -> @value.Cell raise EvalError {
  if at < items.length() {
    items[at]
  } else {
    raise EvalError::Caused("bad-make-arg", "vector!")
  }
}

///|
fn vector_inferred(items : Array[@value.Cell]) -> @value.Cell raise EvalError {
  let mut float = false
  for item in items {
    match item {
      @value.Decimal(_) => float = true
      @value.Integer(_) => ()
      _ => raise EvalError::Caused("bad-make-arg", "vector!")
    }
  }
  if float {
    vector_floats(@value.VectorKind::Float64, @value.Seq(block_of(items), 0))
  } else {
    vector_ints(@value.VectorKind::Int64, @value.Seq(block_of(items), 0))
  }
}

///|
fn block_of(items : Array[@value.Cell]) -> @value.Series {
  let block = @value.Series::block()
  for item in items {
    block.push_item(item) |> ignore
  }
  block
}

///|
fn vector_ints(
  kind : @value.VectorKind,
  data : @value.Cell,
) -> @value.Cell raise EvalError {
  let ints : Array[Int64] = []
  match data {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      for cursor in index..<series.length() {
        match series.item(cursor) {
          Some(@value.Integer(number)) => ints.push(fit_int(number, kind))
          _ => raise EvalError::Caused("bad-make-arg", "vector!")
        }
      }
    _ => raise EvalError::Caused("bad-make-arg", "vector!")
  }
  @value.Vector(@value.Vector::ints(kind, ints))
}

///|
fn vector_floats(
  kind : @value.VectorKind,
  data : @value.Cell,
) -> @value.Cell raise EvalError {
  let floats : Array[Double] = []
  match data {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      for cursor in index..<series.length() {
        match series.item(cursor) {
          Some(@value.Integer(number)) => floats.push(number.to_double())
          Some(@value.Decimal(number)) => floats.push(number)
          _ => raise EvalError::Caused("bad-make-arg", "vector!")
        }
      }
    _ => raise EvalError::Caused("bad-make-arg", "vector!")
  }
  @value.Vector(@value.Vector::floats(kind, floats))
}

///|
fn named_kind(name : String) -> @value.VectorKind? {
  match name {
    "int8!" => Some(@value.VectorKind::Int8)
    "int16!" => Some(@value.VectorKind::Int16)
    "int32!" => Some(@value.VectorKind::Int32)
    "int64!" => Some(@value.VectorKind::Int64)
    "uint8!" => Some(@value.VectorKind::Uint8)
    "uint16!" => Some(@value.VectorKind::Uint16)
    "uint32!" => Some(@value.VectorKind::Uint32)
    "uint64!" => Some(@value.VectorKind::Uint64)
    "float32!" => Some(@value.VectorKind::Float32)
    "float64!" => Some(@value.VectorKind::Float64)
    _ => None
  }
}

///|
fn signed_kind(bits : Int64) -> @value.VectorKind raise EvalError {
  match bits {
    8L => @value.VectorKind::Int8
    16L => @value.VectorKind::Int16
    32L => @value.VectorKind::Int32
    64L => @value.VectorKind::Int64
    _ => raise EvalError::Caused("bad-make-arg", "vector!")
  }
}

///|
fn unsigned_kind(bits : Int64) -> @value.VectorKind raise EvalError {
  match bits {
    8L => @value.VectorKind::Uint8
    16L => @value.VectorKind::Uint16
    32L => @value.VectorKind::Uint32
    64L => @value.VectorKind::Uint64
    _ => raise EvalError::Caused("bad-make-arg", "vector!")
  }
}

///|
fn float_kind(bits : Int64) -> @value.VectorKind raise EvalError {
  match bits {
    32L => @value.VectorKind::Float32
    64L => @value.VectorKind::Float64
    _ => raise EvalError::Caused("bad-make-arg", "vector!")
  }
}

///|
fn fit_int(number : Int64, kind : @value.VectorKind) -> Int64 {
  match kind {
    @value.VectorKind::Int8 => wrap_signed(number, 8)
    @value.VectorKind::Int16 => wrap_signed(number, 16)
    @value.VectorKind::Int32 => wrap_signed(number, 32)
    @value.VectorKind::Uint8 => wrap_unsigned(number, 8)
    @value.VectorKind::Uint16 => wrap_unsigned(number, 16)
    @value.VectorKind::Uint32 => wrap_unsigned(number, 32)
    _ => number
  }
}

///|
fn wrap_unsigned(number : Int64, bits : Int) -> Int64 {
  let mask = (1L << bits) - 1L
  number & mask
}

///|
fn wrap_signed(number : Int64, bits : Int) -> Int64 {
  let wrapped = wrap_unsigned(number, bits)
  let sign = 1L << (bits - 1)
  if wrapped >= sign {
    wrapped - (sign << 1)
  } else {
    wrapped
  }
}

///|
fn vector_word(cell : @value.Cell, name : String) -> Bool {
  match cell {
    @value.Sym(_, lexeme) => lexeme.spelling().to_lower() == name
    _ => false
  }
}
