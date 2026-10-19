///|
fn make_value(
  env : Env,
  datatype : @value.Cell,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  match datatype {
    @value.Type(@value.Object) => make_object(env, None, spec)
    @value.Object(parent) => make_object(env, Some(parent), spec)
    @value.Type(@value.Port) => make_port(env, spec)
    @value.Type(@value.Op) => make_op(spec)
    @value.Type(@value.Percent) => to_percent(spec, true)
    @value.Type(@value.Decimal) => decimal_from(spec)
    @value.Type(@value.Integer) => integer_from(spec)
    @value.Type(@value.Pair) => to_pair(spec)
    @value.Type(@value.Tuple) => to_tuple(spec)
    @value.Type(@value.Money) => to_money(spec)
    @value.Type(@value.Time) => to_time(spec)
    @value.Type(@value.Date) => to_date(spec)
    @value.Type(@value.Bitset) => to_bitset(spec)
    @value.Type(@value.Map) => to_map(spec)
    @value.Type(@value.Vector) => make_vector(spec)
    @value.Type(@value.Image) => make_image(spec)
    @value.Type(@value.Struct) => make_struct(spec)
    @value.Type(@value.Typeset) => make_typeset(env, spec)
    @value.Type(@value.Event) => make_event(None, spec)
    @value.Event(event) => make_event(Some(event), spec)
    @value.Type(@value.Utype) => make_utype(spec)
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn make_op(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Function(func) => @value.Function(func.as_op())
    _ => raise EvalError::Cannot("make")
  }
}

///|
/// Collects top-level set-words, binds the spec to that frame, then evaluates it.
/// A new word starts as `none`, so a spec can read it before its own assignment.
/// An object prototype contributes its words first. Blocks and strings are copied.
/// Maps stay shared, the same way Rebol clones a parent object.
fn make_object(
  env : Env,
  parent : @value.Frame?,
  spec : @value.Cell,
) -> @value.Cell raise EvalError {
  match spec {
    @value.Seq(series, index) if series.datatype() == @value.Block => {
      let frame = match parent {
        Some(base) => clone_object(base)
        None => @value.Frame::new()
      }
      let self_slot = frame.ensure(env.symbols.intern("self"))
      frame.set(self_slot, @value.Object(frame)) |> ignore
      frame.hide(self_slot, true)
      let mut cursor = index
      while cursor < series.length() {
        match series.item(cursor) {
          Some(@value.Sym(@value.SetWord, lexeme)) =>
            if frame.find(lexeme.sym()) is None {
              let slot = frame.ensure(lexeme.sym())
              frame.set(slot, @value.None) |> ignore
            }
          _ => ()
        }
        cursor = cursor + 1
      }
      @bind.bind(@value.Seq(series, index), frame) |> ignore
      do_series(env, series, index) |> ignore
      @value.Object(frame)
    }
    _ => raise EvalError::Cannot("make")
  }
}

///|
fn clone_object(base : @value.Frame) -> @value.Frame {
  let frame = @value.Frame::new()
  for index in 0..<base.length() {
    match base.sym(index) {
      Some(sym) => {
        let slot = frame.ensure(sym)
        let value = match base.get(index) {
          Some(cell) => clone_field(cell, base, frame)
          None => @value.None
        }
        frame.set(slot, value) |> ignore
        if base.is_hidden(index) {
          frame.hide(slot, true)
        }
      }
      None => ()
    }
  }
  frame
}

///|
/// Blocks and strings are copied. A function's body is copied and rebinds
/// only the words that pointed at the prototype, so methods see the clone.
fn clone_field(
  cell : @value.Cell,
  from : @value.Frame,
  to : @value.Frame,
) -> @value.Cell {
  match cell {
    @value.Seq(series, index) => {
      let copied = @value.Seq(series.copy_deep(index), 0)
      @bind.rebind(copied, from, to) |> ignore
      copied
    }
    @value.Function(func) => {
      let body = func.body().copy_deep(0)
      @bind.rebind(@value.Seq(body, 0), from, to) |> ignore
      @value.Function(
        @value.Func::make(
          func.params(),
          func.types(),
          func.lits(),
          func.refines(),
          func.refine_args(),
          func.refine_types(),
          func.spec_words(),
          func.spec_kinds(),
          body,
          func.is_infix(),
          func.frame(),
          func.is_closure(),
        ),
      )
    }
    _ => cell
  }
}

///|
/// Words of an object, in creation order. Map keys that are words become words.
fn words_of(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let block = @value.Series::block()
  match value {
    @value.Object(frame) =>
      for index in 0..<frame.length() {
        match frame.sym(index) {
          Some(sym) =>
            if !frame.is_hidden(index) {
              block.push_item(word_cell(env, env.symbols.canon(sym))) |> ignore
            }
          None => ()
        }
      }
    @value.Map(map) =>
      for index in 0..<map.length() {
        match map.key(index) {
          Some(key) => block.push_item(word_key(key)) |> ignore
          None => ()
        }
      }
    @value.Function(func) =>
      for index in 0..<func.spec_words().length() {
        let sym = func.spec_words()[index]
        let kind = func.spec_kinds()[index]
        block.push_item(func_spec_word(env, sym, kind)) |> ignore
      }
    @value.Handle(_) => block.push_item(word_cell(env, "type")) |> ignore
    _ => raise EvalError::Caused("expect-arg", "words-of")
  }
  @value.Seq(block, 0)
}

///|
fn func_spec_word(env : Env, sym : Int, kind : Int) -> @value.Cell {
  let spelling = env.symbols.canon(sym)
  let lexeme = @value.Lexeme::make(sym, spelling)
  let datatype = if kind == 1 {
    @value.Refinement
  } else if kind == 2 {
    @value.LitWord
  } else {
    @value.Word
  }
  @value.Sym(datatype, lexeme)
}

///|
fn word_key(key : @value.Cell) -> @value.Cell {
  match key {
    @value.Sym(_, lexeme) => @value.Sym(@value.Word, lexeme)
    _ => key
  }
}
