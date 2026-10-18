///|
/// `make typeset! [block! map! object!]`. Repeated names collapse.
/// A word that is not a datatype is `invalid-arg`. A non-block is `bad-make-arg`.
fn make_typeset(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      typeset_block(series, index)
    _ => raise EvalError::Caused("bad-make-arg", "typeset!")
  }
}

///|
fn typeset_block(
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let types : Array[@value.Datatype] = []
  for cursor in index..<series.length() {
    match series.item(cursor) {
      Some(item) => {
        let datatype = typeset_member(item)
        if !typeset_has(types, datatype) {
          types.push(datatype)
        }
      }
      None => ()
    }
  }
  @value.Typeset(@value.Typeset::make(types))
}

///|
fn typeset_member(cell : @value.Cell) -> @value.Datatype raise EvalError {
  match cell {
    @value.Type(datatype) => datatype
    @value.Sym(_, lexeme) =>
      match datatype_named(lexeme.spelling().to_lower()) {
        Some(datatype) => datatype
        None => raise EvalError::Caused("invalid-arg", "")
      }
    _ => raise EvalError::Caused("invalid-arg", "")
  }
}

///|
fn typeset_has(
  types : Array[@value.Datatype],
  datatype : @value.Datatype,
) -> Bool {
  let mut found = false
  for item in types {
    if item == datatype {
      found = true
    }
  }
  found
}

///|
fn typeset_find(
  types : @value.Typeset,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  match value {
    @value.Type(datatype) => @value.Logic(types.contains(datatype))
    _ => raise EvalError::Caused("invalid-arg", "")
  }
}

///|
fn datatype_named(name : String) -> @value.Datatype? {
  match name {
    "unset!" => Some(@value.Unset)
    "none!" => Some(@value.None)
    "logic!" => Some(@value.Logic)
    "integer!" => Some(@value.Integer)
    "decimal!" => Some(@value.Decimal)
    "percent!" => Some(@value.Percent)
    "money!" => Some(@value.Money)
    "char!" => Some(@value.Char)
    "pair!" => Some(@value.Pair)
    "tuple!" => Some(@value.Tuple)
    "time!" => Some(@value.Time)
    "date!" => Some(@value.Date)
    "binary!" => Some(@value.Binary)
    "string!" => Some(@value.String)
    "file!" => Some(@value.File)
    "email!" => Some(@value.Email)
    "url!" => Some(@value.Url)
    "tag!" => Some(@value.Tag)
    "bitset!" => Some(@value.Bitset)
    "image!" => Some(@value.Image)
    "vector!" => Some(@value.Vector)
    "block!" => Some(@value.Block)
    "paren!" => Some(@value.Paren)
    "path!" => Some(@value.Path)
    "set-path!" => Some(@value.SetPath)
    "map!" => Some(@value.Map)
    "datatype!" => Some(@value.Datatype)
    "typeset!" => Some(@value.Typeset)
    "word!" => Some(@value.Word)
    "set-word!" => Some(@value.SetWord)
    "get-word!" => Some(@value.GetWord)
    "lit-word!" => Some(@value.LitWord)
    "refinement!" => Some(@value.Refinement)
    "issue!" => Some(@value.Issue)
    "op!" => Some(@value.Op)
    "closure!" => Some(@value.Closure)
    "function!" => Some(@value.Function)
    "object!" => Some(@value.Object)
    "module!" => Some(@value.Module)
    "error!" => Some(@value.Error)
    "port!" => Some(@value.Port)
    "handle!" => Some(@value.Handle)
    "struct!" => Some(@value.Struct)
    _ => None
  }
}
