///|
/// `make typeset! [block! map! object!]`. Repeated names collapse.
/// A word that is not a datatype is `invalid-arg`. A non-block is `bad-make-arg`.
fn make_typeset(env : Env, spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      typeset_block(env, series, index)
    _ => raise EvalError::Caused("bad-make-arg", "typeset!")
  }
}

///|
fn typeset_block(
  env : Env,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let types : Array[@value.Datatype] = []
  for cursor in index..<series.length() {
    match series.item(cursor) {
      Some(item) => typeset_add(env, types, item)
      None => ()
    }
  }
  @value.Typeset(@value.Typeset::make(types))
}

///|
/// A bound word uses its value. A typeset is merged in. An unbound word is
/// accepted when its spelling is a datatype name.
fn typeset_add(
  env : Env,
  types : Array[@value.Datatype],
  cell : @value.Cell,
) -> Unit raise EvalError {
  match cell {
    @value.Type(datatype) => typeset_push(types, datatype)
    @value.Typeset(set) =>
      for datatype in set.ordered() {
        typeset_push(types, datatype)
      }
    @value.Sym(_, lexeme) =>
      match quiet(env, lexeme) {
        Some(value) => typeset_add(env, types, value)
        None =>
          match datatype_named(lexeme.spelling().to_lower()) {
            Some(datatype) => typeset_push(types, datatype)
            None => raise EvalError::Caused("invalid-arg", "")
          }
      }
    _ => raise EvalError::Caused("invalid-arg", "")
  }
}

///|
fn typeset_push(
  types : Array[@value.Datatype],
  datatype : @value.Datatype,
) -> Unit {
  if !typeset_has(types, datatype) {
    types.push(datatype)
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

///|
/// Presets from `Init_Typesets`, limited to datatypes this interpreter has.
fn install_typesets(env : Env) -> Unit {
  install_typeset(env, "number!", [
    @value.Integer,
    @value.Decimal,
    @value.Percent,
  ])
  install_typeset(env, "scalar!", [
    @value.Integer,
    @value.Decimal,
    @value.Percent,
    @value.Money,
    @value.Char,
    @value.Pair,
    @value.Tuple,
    @value.Time,
    @value.Date,
  ])
  install_typeset(env, "any-word!", [
    @value.Word,
    @value.SetWord,
    @value.GetWord,
    @value.LitWord,
    @value.Refinement,
    @value.Issue,
  ])
  install_typeset(env, "any-path!", [@value.Path, @value.SetPath])
  install_typeset(env, "any-function!", [
    @value.Op,
    @value.Closure,
    @value.Function,
  ])
  install_typeset(env, "any-string!", [
    @value.String,
    @value.File,
    @value.Email,
    @value.Url,
    @value.Tag,
  ])
  install_typeset(env, "any-block!", [
    @value.Block,
    @value.Paren,
    @value.Path,
    @value.SetPath,
  ])
  install_typeset(env, "series!", [
    @value.Binary,
    @value.String,
    @value.File,
    @value.Email,
    @value.Url,
    @value.Tag,
    @value.Image,
    @value.Vector,
    @value.Block,
    @value.Paren,
    @value.Path,
    @value.SetPath,
  ])
  install_typeset(env, "any-object!", [
    @value.Object,
    @value.Module,
    @value.Error,
    @value.Port,
  ])
  install_typeset(env, "any-type!", [
    @value.Unset,
    @value.None,
    @value.Logic,
    @value.Integer,
    @value.Decimal,
    @value.Percent,
    @value.Money,
    @value.Char,
    @value.Pair,
    @value.Tuple,
    @value.Time,
    @value.Date,
    @value.Binary,
    @value.String,
    @value.File,
    @value.Email,
    @value.Url,
    @value.Tag,
    @value.Bitset,
    @value.Image,
    @value.Vector,
    @value.Block,
    @value.Paren,
    @value.Path,
    @value.SetPath,
    @value.Map,
    @value.Datatype,
    @value.Typeset,
    @value.Word,
    @value.SetWord,
    @value.GetWord,
    @value.LitWord,
    @value.Refinement,
    @value.Issue,
    @value.Op,
    @value.Closure,
    @value.Function,
    @value.Object,
    @value.Module,
    @value.Error,
    @value.Port,
    @value.Event,
    @value.Handle,
    @value.Struct,
    @value.Utype,
  ])
}

///|
fn install_typeset(
  env : Env,
  name : String,
  types : Array[@value.Datatype],
) -> Unit {
  install(env, name, @value.Typeset(@value.Typeset::make(types)))
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
    "event!" => Some(@value.Event)
    "handle!" => Some(@value.Handle)
    "struct!" => Some(@value.Struct)
    "utype!" => Some(@value.Utype)
    _ => None
  }
}
