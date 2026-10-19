///|
/// Copies `body` and binds parameter words onto a fresh frame.
/// Words that are not parameters keep the binding they already have.
fn build_func(
  env : Env,
  spec : @value.Cell,
  body : @value.Cell,
  closure : Bool,
) -> @value.Cell raise EvalError {
  let names = spec_names(env, spec)
  let frame = @value.Frame::new()
  for sym in names.args {
    frame.ensure(sym) |> ignore
  }
  for sym in names.locals {
    frame.ensure(sym) |> ignore
  }
  for sym in names.refines {
    frame.ensure(sym) |> ignore
  }
  for group in names.refine_args {
    for sym in group {
      frame.ensure(sym) |> ignore
    }
  }
  match copied_block(body) {
    Some(series) => {
      @bind.bind(@value.Seq(series, 0), frame) |> ignore
      @value.Function(
        @value.Func::make(
          names.args,
          names.types,
          names.lits,
          names.refines,
          names.refine_args,
          names.refine_types,
          names.words,
          names.kinds,
          series,
          false,
          frame,
          closure,
        ),
      )
    }
    None => raise EvalError::Cannot("func")
  }
}

///|
priv struct FuncSpec {
  args : Array[Int]
  types : Array[Array[@value.Datatype]]
  lits : Array[Bool]
  locals : Array[Int]
  refines : Array[Int]
  refine_args : Array[Array[Int]]
  refine_types : Array[Array[Array[@value.Datatype]]]
  words : Array[Int]
  kinds : Array[Int]
}

///|
/// Words before a refinement are arguments. `/local` words stay in the frame.
/// Other refinements take the words that follow them only when the call sets them.
/// A type block or a string after a word or refinement is part of the spec.
fn spec_names(env : Env, spec : @value.Cell) -> FuncSpec raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let built : FuncSpec = {
        args: [],
        types: [],
        lits: [],
        locals: [],
        refines: [],
        refine_args: [],
        refine_types: [],
        words: [],
        kinds: [],
      }
      let mut cursor = index
      let mut mode = 0
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.Word, lexeme)) =>
            cursor = push_param(
              env,
              built,
              mode,
              lexeme.sym(),
              false,
              series,
              cursor,
            )
          Some(@value.Sym(@value.LitWord, lexeme)) =>
            cursor = push_param(
              env,
              built,
              mode,
              lexeme.sym(),
              true,
              series,
              cursor,
            )
          Some(@value.Sym(@value.Refinement, lexeme)) => {
            built.words.push(lexeme.sym())
            built.kinds.push(1)
            if lexeme.spelling() == "local" {
              mode = -1
            } else {
              built.refines.push(lexeme.sym())
              built.refine_args.push([])
              built.refine_types.push([])
              mode = built.refines.length()
            }
            cursor = after_note(series, cursor + 1)
          }
          Some(@value.Seq(text, _)) if text.datatype() == @value.String =>
            cursor = cursor + 1
          _ => raise EvalError::Cannot("func")
        }
      }
      built
    }
    _ => raise EvalError::Cannot("func")
  }
}

///|
fn push_param(
  env : Env,
  built : FuncSpec,
  mode : Int,
  sym : Int,
  lit : Bool,
  series : @value.Series,
  cursor : Int,
) -> Int raise EvalError {
  let next = cursor + 1
  built.words.push(sym)
  built.kinds.push(if lit { 2 } else { 0 })
  if mode == 0 {
    built.args.push(sym)
    built.lits.push(lit)
    built.types.push(arg_types(env, series, next))
    after_param(series, cursor)
  } else if lit {
    raise EvalError::Cannot("func")
  } else if mode < 0 {
    built.locals.push(sym)
    after_param(series, cursor)
  } else {
    built.refine_args[mode - 1].push(sym)
    built.refine_types[mode - 1].push(arg_types(env, series, next))
    after_param(series, cursor)
  }
}

///|
/// A parameter may be followed by a type block and a description string.
fn after_param(series : @value.Series, cursor : Int) -> Int {
  let mut next = cursor + 1
  if spec_block(series, next) {
    next = next + 1
  }
  if spec_string(series, next) {
    next = next + 1
  }
  next
}

///|
/// A refinement may be followed by a description string.
fn after_note(series : @value.Series, cursor : Int) -> Int {
  if spec_string(series, cursor) {
    cursor + 1
  } else {
    cursor
  }
}

///|
fn spec_block(series : @value.Series, index : Int) -> Bool {
  match series.item(index) {
    Some(@value.Seq(block, _)) => block.datatype() == @value.Block
    _ => false
  }
}

///|
fn spec_string(series : @value.Series, index : Int) -> Bool {
  match series.item(index) {
    Some(@value.Seq(text, _)) => text.datatype() == @value.String
    _ => false
  }
}

///|
fn arg_types(
  env : Env,
  series : @value.Series,
  cursor : Int,
) -> Array[@value.Datatype] raise EvalError {
  match series.item(cursor) {
    Some(@value.Seq(block, index)) if block.datatype() == @value.Block => {
      let types : Array[@value.Datatype] = []
      let mut at = index
      while at < block.length() {
        match block.item(at) {
          Some(@value.Sym(@value.Word, lexeme)) =>
            types.push(named_type(env, lexeme))
          _ => raise EvalError::Cannot("func")
        }
        at = at + 1
      }
      types
    }
    _ => []
  }
}

///|
fn named_type(
  env : Env,
  lexeme : @value.Lexeme,
) -> @value.Datatype raise EvalError {
  match env.user.find(lexeme.sym()) {
    Some(slot) =>
      match env.user.get(slot) {
        Some(@value.Type(datatype)) => datatype
        _ => raise EvalError::Cannot("func")
      }
    None => raise EvalError::Cannot("func")
  }
}

///|
fn copied_block(cell : @value.Cell) -> @value.Series? {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      Some(series.copy_deep(index))
    _ => None
  }
}

///|
/// Writes arguments into the function frame, then evaluates its body.
fn call_user(
  env : Env,
  func : @value.Func,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let (frame, body) = if func.is_closure() {
    let fresh = func.frame().copy_shape()
    let copied = func.body().copy_deep(0)
    @bind.bind(@value.Seq(copied, 0), fresh) |> ignore
    (fresh, copied)
  } else {
    (func.frame(), func.body())
  }
  let names = func.params()
  let types = func.types()
  let mut index = 0
  while index < names.length() {
    check_type(args[index], types, index)
    write_slot(frame, names[index], args[index])
    index = index + 1
  }
  let mut taken = names.length()
  let refines = func.refines()
  let groups = func.refine_args()
  let mut which = 0
  while which < refines.length() {
    write_slot(frame, refines[which], @value.Logic(false))
    for sym in groups[which] {
      write_slot(frame, sym, @value.None)
    }
    which = which + 1
  }
  for sym in active {
    match refine_at(func, sym) {
      Some(at) => {
        write_slot(frame, sym, @value.Logic(true))
        let mut nth = 0
        for arg in groups[at] {
          check_type(args[taken], func.refine_types()[at], nth)
          write_slot(frame, arg, args[taken])
          taken = taken + 1
          nth = nth + 1
        }
      }
      None => raise EvalError::Cannot("func")
    }
  }
  let _ = taken
  do_series(env, body, 0) catch {
    EvalError::Returned(cell) => cell
    error => raise error
  }
}

///|
fn check_type(
  value : @value.Cell,
  types : Array[Array[@value.Datatype]],
  index : Int,
) -> Unit raise EvalError {
  if index < types.length() && types[index].length() > 0 {
    let got = value.datatype()
    let mut allowed = false
    for want in types[index] {
      if got == want {
        allowed = true
      }
    }
    if !allowed {
      raise EvalError::Cannot("func")
    }
  }
}

///|
fn write_slot(
  frame : @value.Frame,
  sym : Int,
  value : @value.Cell,
) -> Unit raise EvalError {
  match frame.find(sym) {
    Some(slot) => store(frame, slot, value)
    None => raise EvalError::Cannot("func")
  }
}

///|
fn refine_at(func : @value.Func, sym : Int) -> Int? {
  let names = func.refines()
  let mut index = 0
  while index < names.length() {
    if names[index] == sym {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn taken_count(func : @value.Func, active : Array[Int]) -> Int raise EvalError {
  let mut count = func.arity()
  for sym in active {
    match refine_at(func, sym) {
      Some(index) => count = count + func.refine_args()[index].length()
      None => raise EvalError::Cannot("func")
    }
  }
  count
}

///|
fn invoke(env : Env, func : @value.Func) -> @value.Cell raise EvalError {
  if func.arity() != 0 {
    raise EvalError::MissingArg("argument")
  } else if func.code() == 0 {
    call_user(env, func, [], [])
  } else {
    apply(env, func, [])
  }
}

///|
/// `do` of a word fetches it. A function is called. A fetched block is not.
fn perform_do(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Sym(_, lexeme) => {
      let value = lookup_word(env, lexeme)
      match value {
        @value.Function(func) => invoke(env, func)
        _ => value
      }
    }
    @value.Function(func) => invoke(env, func)
    @value.Seq(series, _) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => eval(env, cell)
    @value.Seq(series, index) if series.datatype() == @value.String =>
      do_text(env, text_from(series, index))
    @value.Seq(series, index) if series.datatype() == @value.File =>
      do_file(env, text_from(series, index))
    _ => cell
  }
}

///|
/// Load the file first. A path with a slash then runs in that file's
/// directory, and the previous directory is restored afterwards.
fn do_file(env : Env, path : String) -> @value.Cell raise EvalError {
  let loaded = load_code(env, drop_bom(read_binary(path)))
  match file_parent(path) {
    None => eval(env, loaded)
    Some(dir) => {
      let saved = perform_what_dir()
      if c_change_dir(dir, dir.length()) != 0 {
        raise EvalError::Cannot("access")
      }
      errdefer restore_dir(saved)
      let result = eval(env, loaded)
      let _ = perform_change_dir(saved)
      result
    }
  }
}

///|
fn file_parent(path : String) -> String? {
  let mut at = -1
  let mut index = 0
  for char in path {
    if char == '/' {
      at = index
    }
    index = index + 1
  }
  if at < 0 {
    None
  } else {
    Some(path[0:at + 1].to_owned())
  }
}

///|
fn restore_dir(saved : @value.Cell) -> Unit {
  try {
    let _ = perform_change_dir(saved)
  } catch {
    _ => ()
  }
}

///|
fn lookup_word(
  env : Env,
  lexeme : @value.Lexeme,
) -> @value.Cell raise EvalError {
  match lexeme.binding() {
    @value.Bound(frame, slot) => defined(frame, slot, lexeme.spelling())
    @value.Unbound =>
      match env.user.find(lexeme.sym()) {
        Some(slot) => defined(env.user, slot, lexeme.spelling())
        None => raise EvalError::NoValue(lexeme.spelling())
      }
  }
}

///|
/// Evaluates a block. A failure inside it comes back as `error!`.
/// `return` is not a failure and keeps traveling to the function that called it.
fn perform_try(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, _) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren =>
      eval(env, cell) catch {
        EvalError::Returned(value) => raise EvalError::Returned(value)
        EvalError::Broken => raise EvalError::Broken
        EvalError::Continued => raise EvalError::Continued
        EvalError::Thrown(name, value) => raise EvalError::Thrown(name, value)
        EvalError::Stopped(pos) => raise EvalError::Stopped(pos)
        EvalError::Quit => raise EvalError::Quit
        error => error.to_cell()
      }
    _ => cell
  }
}

///|
/// Evaluates each expression in a block or paren. Unset results are left
/// out. `none` stays `none`. Any other value is returned as it is.
fn reduce_block(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.None => @value.None
    @value.Seq(series, index) if series.datatype() == @value.Block ||
      series.datatype() == @value.Paren => {
      let out = @value.Series::block()
      let mut cursor = index
      while cursor < series.length() {
        let stepped = do_next_at(env, series, cursor)
        if stepped.1 <= cursor {
          raise EvalError::Cannot("reduce")
        }
        match stepped.0 {
          @value.Unset => ()
          value => out.push_item(value) |> ignore
        }
        cursor = stepped.1
      }
      @value.Seq(out, 0)
    }
    _ => cell
  }
}
