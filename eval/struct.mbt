///|
/// `make struct! [a [int8!] b [int16!]]`. Fields start at zero.
/// `float!` is `float32!` and `double!` is `float64!`. An empty spec is
/// `malconstruct`. Anything other than a block is `bad-make-arg`.
fn make_struct(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      struct_block(series, index)
    _ => raise EvalError::Caused("bad-make-arg", "struct!")
  }
}

///|
fn struct_block(
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
  let mut cursor = 0
  while cursor < items.length() && struct_text(items[cursor]) {
    cursor = cursor + 1
  }
  if cursor < items.length() && struct_block_item(items[cursor]) {
    cursor = cursor + 1
  }
  while cursor < items.length() && struct_text(items[cursor]) {
    cursor = cursor + 1
  }
  let fields : Array[@value.StructField] = []
  while cursor < items.length() {
    match items[cursor] {
      @value.Sym(_, lexeme) => {
        cursor = cursor + 1
        if cursor >= items.length() || !struct_block_item(items[cursor]) {
          raise EvalError::Caused("malconstruct", "")
        }
        fields.push(struct_field(lexeme.spelling(), items[cursor]))
        cursor = cursor + 1
        while cursor < items.length() && struct_text(items[cursor]) {
          cursor = cursor + 1
        }
      }
      _ => raise EvalError::Caused("malconstruct", "")
    }
  }
  if fields.length() == 0 {
    raise EvalError::Caused("malconstruct", "")
  }
  @value.Struct(@value.StructValue::make(fields))
}

///|
fn struct_field(
  name : String,
  spec : @value.Cell,
) -> @value.StructField raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let items : Array[@value.Cell] = []
      for cursor in index..<series.length() {
        match series.item(cursor) {
          Some(item) => items.push(item)
          None => ()
        }
      }
      if items.length() == 0 {
        raise EvalError::Caused("invalid-arg", "")
      }
      match items[0] {
        @value.Sym(_, lexeme) => {
          let kind = struct_kind(lexeme.spelling().to_lower())
          if items.length() == 1 {
            @value.StructField::make(name, kind, 1, false)
          } else if items.length() == 2 {
            let dimension = struct_dimension(items[1])
            @value.StructField::make(name, kind, dimension, true)
          } else {
            raise EvalError::Caused("invalid-arg", "")
          }
        }
        _ => raise EvalError::Caused("invalid-arg", "")
      }
    }
    _ => raise EvalError::Caused("invalid-arg", "")
  }
}

///|
fn struct_kind(name : String) -> @value.StructKind raise EvalError {
  match name {
    "int8!" => @value.StructKind::Int8
    "int16!" => @value.StructKind::Int16
    "int32!" => @value.StructKind::Int32
    "int64!" => @value.StructKind::Int64
    "uint8!" => @value.StructKind::Uint8
    "uint16!" => @value.StructKind::Uint16
    "uint32!" => @value.StructKind::Uint32
    "uint64!" => @value.StructKind::Uint64
    "float!" | "float32!" => @value.StructKind::Float32
    "double!" | "float64!" => @value.StructKind::Float64
    "word!" => @value.StructKind::Word
    _ => raise EvalError::Caused("invalid-arg", "")
  }
}

///|
fn struct_dimension(cell : @value.Cell) -> Int raise EvalError {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let mut count = 0
      let mut found : Int? = None
      for cursor in index..<series.length() {
        match series.item(cursor) {
          Some(@value.Integer(n)) if count == 0 && n >= 0L && n <= 2147483647L =>
            found = Some(n.to_int())
          Some(_) => raise EvalError::Caused("invalid-arg", "")
          None => ()
        }
        count = count + 1
      }
      match found {
        Some(n) if count == 1 => n
        _ => raise EvalError::Caused("invalid-arg", "")
      }
    }
    _ => raise EvalError::Caused("invalid-arg", "")
  }
}

///|
fn struct_text(cell : @value.Cell) -> Bool {
  match cell {
    @value.Seq(series, _) => @value.text_series(series.datatype())
    _ => false
  }
}

///|
fn struct_field_at(
  env : Env,
  fields : @value.StructValue,
  selector : @value.Cell,
) -> @value.Cell raise EvalError {
  match selector {
    @value.Sym(_, lexeme) => {
      let name = env.symbols.canon(lexeme.sym())
      match fields.get(name) {
        Some(cell) => cell
        None => raise EvalError::InvalidPath(lexeme.spelling())
      }
    }
    _ => raise EvalError::InvalidPath("struct")
  }
}

///|
fn struct_block_item(cell : @value.Cell) -> Bool {
  match cell {
    @value.Seq(series, _) => series.datatype() == @value.Block
    _ => false
  }
}
