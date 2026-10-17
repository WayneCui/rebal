///|
/// Evaluates a source string in the user frame.
/// A `return` with no function around it becomes an error.
pub fn run(env : Env, source : String) -> @value.Cell raise EvalError {
  eval(env, load(env, source)) catch {
    EvalError::Returned(_) => raise EvalError::NoReturn
    EvalError::Broken => raise EvalError::NoBreak
    EvalError::Continued => raise EvalError::NoContinue
    EvalError::Thrown(name, _) => raise EvalError::NoThrow(name)
    error => raise error
  }
}

///|
/// Evaluates a block, paren, or string. Other values are returned as they are.
pub fn eval(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Seq(series, index) =>
      match series.datatype() {
        @value.String => eval(env, load(env, text_from(series, index)))
        @value.Block | @value.Paren => do_series(env, series, index)
        _ => cell
      }
    _ => cell
  }
}

///|
/// Evaluates one expression. The remainder shares the input series.
/// A non-series input returns that value and `none`.
pub fn do_next(
  env : Env,
  cell : @value.Cell,
) -> (@value.Cell, @value.Cell) raise EvalError {
  match cell {
    @value.Seq(series, index) =>
      match series.datatype() {
        @value.String => do_next(env, load(env, text_from(series, index)))
        @value.Block | @value.Paren => {
          let (value, next) = do_next_at(env, series, index)
          (value, @value.Seq(series, next))
        }
        _ => (cell, @value.None)
      }
    _ => (cell, @value.None)
  }
}

///|
fn text_from(series : @value.Series, index : Int) -> String raise EvalError {
  let buf = StringBuilder()
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.code(cursor) {
      Some(code) =>
        match code.to_char() {
          Some(char) => buf.write_char(char)
          None => raise EvalError::BadSource("char")
        }
      None => ()
    }
    cursor = cursor + 1
  }
  buf.to_string()
}

///|
fn do_series(
  env : Env,
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let mut cursor = index
  let mut result = @value.Cell::Unset
  while cursor < series.length() {
    let (value, next) = do_next_at(env, series, cursor)
    if next <= cursor {
      raise EvalError::Cannot("eval")
    }
    result = value
    cursor = next
  }
  result
}

///|
fn do_next_at(
  env : Env,
  series : @value.Series,
  index : Int,
) -> (@value.Cell, Int) raise EvalError {
  if index >= series.length() {
    (@value.Unset, index)
  } else {
    let started = eval_atom(env, series, index)
    let mut value = started.0
    let mut cursor = started.1
    let mut running = true
    while running {
      match infix_at(env, series, cursor) {
        Some(func) =>
          if cursor + 1 >= series.length() {
            raise EvalError::MissingArg("op")
          } else {
            let right = eval_atom(env, series, cursor + 1)
            if right.1 <= cursor {
              raise EvalError::Cannot("eval")
            }
            value = apply(env, func, [value, right.0])
            cursor = right.1
          }
        None => running = false
      }
    }
    (value, cursor)
  }
}

///|
fn eval_atom(
  env : Env,
  series : @value.Series,
  index : Int,
) -> (@value.Cell, Int) raise EvalError {
  match series.item(index) {
    None => (@value.Unset, index)
    Some(@value.Sym(@value.SetWord, lexeme)) => {
      if index + 1 >= series.length() {
        raise EvalError::MissingArg(lexeme.spelling())
      }
      let (value, next) = do_next_at(env, series, index + 1)
      assign(env, series, index, lexeme, value)
      (value, next)
    }
    Some(@value.Sym(@value.GetWord, lexeme)) =>
      (fetch(env, series, index, @value.GetWord, lexeme), index + 1)
    Some(@value.Sym(@value.LitWord, lexeme)) =>
      (
        @value.Sym(
          @value.Word,
          @value.Lexeme::make(lexeme.sym(), lexeme.spelling()),
        ),
        index + 1,
      )
    Some(@value.Function(func)) =>
      if func.is_infix() {
        raise EvalError::OpArg("op")
      } else {
        call(env, series, index + 1, func, [])
      }
    Some(@value.Seq(nested, nested_index)) if is_set_path(nested) => {
      if index + 1 >= series.length() {
        raise EvalError::MissingArg("path")
      }
      let (value, next) = do_next_at(env, series, index + 1)
      path_set(env, nested, nested_index, value) |> ignore
      (value, next)
    }
    Some(@value.Seq(nested, nested_index)) if nested.datatype() == @value.Path => {
      let head = path_head(env, nested, nested_index)
      match head {
        @value.Function(func) if !func.is_infix() =>
          call(
            env,
            series,
            index + 1,
            func,
            path_refines(nested, nested_index + 1),
          )
        _ => {
          let value = path_get(env, nested, nested_index)
          match value {
            @value.Function(func) if !func.is_infix() =>
              call(env, series, index + 1, func, [])
            _ => (value, index + 1)
          }
        }
      }
    }
    Some(@value.Sym(@value.Word, lexeme)) => {
      let value = fetch(env, series, index, @value.Word, lexeme)
      match value {
        @value.Function(func) =>
          if func.is_infix() {
            raise EvalError::OpArg(lexeme.spelling())
          } else {
            call(env, series, index + 1, func, [])
          }
        _ => (value, index + 1)
      }
    }
    Some(@value.Seq(nested, nested_index)) =>
      if nested.datatype() == @value.Paren {
        (do_series(env, nested, nested_index), index + 1)
      } else {
        (series.item(index).unwrap(), index + 1)
      }
    Some(cell) => (cell, index + 1)
  }
}

///|
fn call(
  env : Env,
  series : @value.Series,
  index : Int,
  func : @value.Func,
  active : Array[Int],
) -> (@value.Cell, Int) raise EvalError {
  if func.code() != 0 &&
    active.length() > 0 &&
    func.code() != native_find &&
    func.code() != native_sort &&
    func.code() != native_call &&
    func.code() != native_now {
    raise EvalError::Cannot("func")
  }
  let args : Array[@value.Cell] = []
  let mut cursor = index
  let count = if func.code() == native_find && named(env, active, "part") {
    func.arity() + 1
  } else if func.code() == native_call {
    func.arity() + call_extra(env, active)
  } else if func.code() == 0 {
    taken_count(func, active)
  } else {
    func.arity()
  }
  let quoted = func.lits()
  for nth in 0..<count {
    if cursor >= series.length() {
      raise EvalError::MissingArg("argument")
    } else if func.code() == 0 && nth < quoted.length() && quoted[nth] {
      match series.item(cursor) {
        Some(cell) => {
          args.push(cell)
          cursor = cursor + 1
        }
        None => raise EvalError::MissingArg("argument")
      }
    } else {
      let (arg, next) = do_next_at(env, series, cursor)
      args.push(arg)
      cursor = next
    }
  }
  if func.code() == native_find {
    (perform_find(env, args, active), cursor)
  } else if func.code() == native_sort {
    (perform_sort(env, args, active), cursor)
  } else if func.code() == native_call {
    (perform_call(env, args, active), cursor)
  } else if func.code() == native_now {
    (perform_now(env, active), cursor)
  } else if func.code() == 0 {
    (call_user(env, func, args, active), cursor)
  } else {
    (apply(env, func, args), cursor)
  }
}

///|
fn named(env : Env, active : Array[Int], spelling : String) -> Bool {
  let sym = env.symbols.intern(spelling)
  let mut found = false
  for active_sym in active {
    if active_sym == sym {
      found = true
    }
  }
  found
}

///|
fn path_refines(
  series : @value.Series,
  index : Int,
) -> Array[Int] raise EvalError {
  let names : Array[Int] = []
  let mut cursor = index
  while cursor < series.length() {
    match series.item(cursor) {
      Some(@value.Sym(_, lexeme)) => names.push(lexeme.sym())
      _ => raise EvalError::Cannot("func")
    }
    cursor = cursor + 1
  }
  names
}

///|
fn apply(
  env : Env,
  func : @value.Func,
  args : Array[@value.Cell],
) -> @value.Cell raise EvalError {
  if func.code() == 0 {
    call_user(env, func, args, [])
  } else if func.code() == native_add {
    from_action(@action.add(args[0], args[1]))
  } else if func.code() == native_subtract {
    from_action(@action.subtract(args[0], args[1]))
  } else if func.code() == native_multiply {
    from_action(@action.multiply(args[0], args[1]))
  } else if func.code() == native_append {
    from_action(@action.append(args[0], args[1]))
  } else if func.code() == native_find {
    from_action(@action.find(args[0], args[1]))
  } else if func.code() == native_pick {
    from_action(@action.pick(args[0], args[1]))
  } else if func.code() == native_length {
    from_action(@action.length(args[0]))
  } else if func.code() == native_first {
    from_action(@action.first(args[0]))
  } else if func.code() == native_copy {
    from_action(@action.copy(args[0]))
  } else if func.code() == native_insert {
    from_action(@action.insert(args[0], args[1]))
  } else if func.code() == native_remove {
    from_action(@action.remove(args[0]))
  } else if func.code() == native_func {
    build_func(env, args[0], args[1], false)
  } else if func.code() == native_function {
    perform_function(env, args[0], args[1])
  } else if func.code() == native_use {
    perform_use(env, args[0], args[1])
  } else if func.code() == native_cause_error {
    perform_cause_error(args[0], args[1], args[2])
  } else if func.code() == native_closure {
    build_func(env, args[0], args[1], true)
  } else if func.code() == native_does {
    build_func(env, @value.Seq(@value.Series::block(), 0), args[0], false)
  } else if func.code() == native_make {
    make_value(env, args[0], args[1])
  } else if func.code() == native_reduce {
    reduce_block(env, args[0])
  } else if func.code() == native_do {
    perform_do(env, args[0])
  } else if func.code() == native_mold {
    from_action(@action.mold(args[0]))
  } else if func.code() == native_form {
    from_action(@action.form(args[0]))
  } else if func.code() == native_type {
    @value.Type(args[0].datatype())
  } else if func.code() == native_try {
    perform_try(env, args[0])
  } else if func.code() == native_equal {
    @value.Logic(@action.equal(args[0], args[1]))
  } else if func.code() == native_not_equal {
    @value.Logic(!@action.equal(args[0], args[1]))
  } else if func.code() == native_lesser {
    logic_order(@action.lesser(args[0], args[1]))
  } else if func.code() == native_greater {
    logic_order(@action.greater(args[0], args[1]))
  } else if func.code() == native_if {
    perform_if(env, args[0], args[1])
  } else if func.code() == native_either {
    perform_either(env, args[0], args[1], args[2])
  } else if func.code() == native_return {
    raise EvalError::Returned(args[0])
  } else if func.code() == native_while {
    perform_while(env, args[0], args[1])
  } else if func.code() == native_until {
    perform_until(env, args[0])
  } else if func.code() == native_loop {
    perform_loop(env, args[0], args[1])
  } else if func.code() == native_break {
    raise EvalError::Broken
  } else if func.code() == native_quit {
    raise EvalError::Quit
  } else if func.code() == native_foreach {
    perform_foreach(env, args[0], args[1], args[2])
  } else if func.code() == native_continue {
    raise EvalError::Continued
  } else if func.code() == native_not {
    @action.logic_not(args[0])
  } else if func.code() == native_and {
    @action.logic_and(args[0], args[1])
  } else if func.code() == native_or {
    @action.logic_or(args[0], args[1])
  } else if func.code() == native_any {
    perform_any(env, args[0])
  } else if func.code() == native_all {
    perform_all(env, args[0])
  } else if func.code() == native_case {
    perform_case(env, args[0])
  } else if func.code() == native_switch {
    perform_switch(env, args[0], args[1])
  } else if func.code() == native_lesser_or_equal {
    logic_order(@action.lesser_or_equal(args[0], args[1]))
  } else if func.code() == native_greater_or_equal {
    logic_order(@action.greater_or_equal(args[0], args[1]))
  } else if func.code() == native_strict_equal {
    @value.Logic(@action.strict_equal(args[0], args[1]))
  } else if func.code() == native_next {
    from_action(@action.next(args[0]))
  } else if func.code() == native_back {
    from_action(@action.back(args[0]))
  } else if func.code() == native_head {
    from_action(@action.head(args[0]))
  } else if func.code() == native_tail {
    from_action(@action.tail(args[0]))
  } else if func.code() == native_skip {
    from_action(@action.skip(args[0], args[1]))
  } else if func.code() == native_at {
    from_action(@action.at(args[0], args[1]))
  } else if func.code() == native_index {
    from_action(@action.index(args[0]))
  } else if func.code() == native_head_q {
    from_action(@action.head_q(args[0]))
  } else if func.code() == native_series_q {
    perform_series_q(args[0])
  } else if func.code() == native_tail_q {
    from_action(@action.tail_q(args[0]))
  } else if func.code() == native_poke {
    from_action(@action.poke(args[0], args[1], args[2]))
  } else if func.code() == native_get {
    perform_get(env, args[0])
  } else if func.code() == native_set {
    perform_set(env, args[0], args[1])
  } else if func.code() == native_unset {
    perform_unset(env, args[0])
  } else if func.code() == native_in {
    perform_in(env, args[0], args[1])
  } else if func.code() == native_value_q {
    perform_value_q(env, args[0])
  } else if func.code() == native_none_q {
    perform_none_q(args[0])
  } else if func.code() == native_unset_q {
    perform_unset_q(env, args[0])
  } else if func.code() == native_bind {
    perform_bind(env, args[0], args[1])
  } else if func.code() == native_unbind {
    perform_unbind(args[0])
  } else if func.code() == native_exit {
    raise EvalError::Returned(@value.Unset)
  } else if func.code() == native_unless {
    perform_unless(env, args[0], args[1])
  } else if func.code() == native_also {
    let _ = args[1]
    args[0]
  } else if func.code() == native_comment {
    let _ = args[0]
    @value.Unset
  } else if func.code() == native_catch {
    perform_catch(env, args[0], args[1])
  } else if func.code() == native_throw {
    perform_throw(args[0], args[1])
  } else if func.code() == native_compose {
    perform_compose(env, args[0])
  } else if func.code() == native_to {
    perform_to(args[0], args[1])
  } else if func.code() == native_divide {
    from_action(@action.divide(args[0], args[1]))
  } else if func.code() == native_remainder {
    from_action(@action.remainder(args[0], args[1]))
  } else if func.code() == native_power {
    from_action(@action.power(args[0], args[1]))
  } else if func.code() == native_negate {
    from_action(@action.negate(args[0]))
  } else if func.code() == native_absolute {
    from_action(@action.absolute(args[0]))
  } else if func.code() == native_odd {
    from_action(@action.odd_q(args[0]))
  } else if func.code() == native_even {
    from_action(@action.even_q(args[0]))
  } else if func.code() == native_negative {
    from_action(@action.negative_q(args[0]))
  } else if func.code() == native_positive {
    from_action(@action.positive_q(args[0]))
  } else if func.code() == native_zero {
    from_action(@action.zero_q(args[0]))
  } else if func.code() == native_min {
    from_action(@action.minimum(args[0], args[1]))
  } else if func.code() == native_max {
    from_action(@action.maximum(args[0], args[1]))
  } else if func.code() == native_round {
    from_action(@action.round(args[0]))
  } else if func.code() == native_random {
    from_action(@action.random(args[0]))
  } else if func.code() == native_complement {
    from_action(@action.complement(args[0]))
  } else if func.code() == native_shift {
    from_action(@action.shift(args[0], args[1]))
  } else if func.code() == native_shift_left {
    from_action(@action.shift_left(args[0], args[1]))
  } else if func.code() == native_shift_right {
    from_action(@action.shift_right(args[0], args[1]))
  } else if func.code() == native_clear {
    from_action(@action.clear(args[0]))
  } else if func.code() == native_take {
    from_action(@action.take(args[0]))
  } else if func.code() == native_reverse {
    from_action(@action.reverse(args[0]))
  } else if func.code() == native_swap {
    from_action(@action.swap(args[0], args[1]))
  } else if func.code() == native_change {
    from_action(@action.change(args[0], args[1]))
  } else if func.code() == native_trim {
    from_action(@action.trim(args[0]))
  } else if func.code() == native_select {
    from_action(@action.select(args[0], args[1]))
  } else if func.code() == native_union {
    from_action(@action.union(args[0], args[1]))
  } else if func.code() == native_intersect {
    from_action(@action.intersect(args[0], args[1]))
  } else if func.code() == native_difference {
    from_action(@action.difference(args[0], args[1]))
  } else if func.code() == native_exclude {
    from_action(@action.exclude(args[0], args[1]))
  } else if func.code() == native_unique {
    from_action(@action.unique(args[0]))
  } else if func.code() == native_lowercase {
    from_action(@action.lowercase(args[0]))
  } else if func.code() == native_uppercase {
    from_action(@action.uppercase(args[0]))
  } else if func.code() == native_deline {
    from_action(@action.deline(args[0]))
  } else if func.code() == native_enline {
    from_action(@action.enline(args[0]))
  } else if func.code() == native_detab {
    from_action(@action.detab(args[0]))
  } else if func.code() == native_entab {
    from_action(@action.entab(args[0]))
  } else if func.code() == native_dehex {
    from_action(@action.dehex(args[0]))
  } else if func.code() == native_enhex {
    from_action(@action.enhex(args[0]))
  } else if func.code() == native_parse {
    perform_parse(env, args[0], args[1])
  } else if func.code() == native_load {
    perform_load(env, args[0])
  } else if func.code() == native_save {
    perform_save(args[0], args[1])
  } else if func.code() == native_module {
    perform_module(env, args[0], args[1])
  } else if func.code() == native_import {
    perform_import(env, args[0])
  } else if func.code() == native_protect {
    perform_protect(env, args[0], true)
  } else if func.code() == native_unprotect {
    perform_protect(env, args[0], false)
  } else if func.code() == native_protected_q {
    perform_protected_q(env, args[0])
  } else if func.code() == native_open {
    perform_open(env, args[0])
  } else if func.code() == native_close {
    perform_close(env, args[0])
  } else if func.code() == native_read {
    perform_read(env, args[0])
  } else if func.code() == native_write {
    perform_write(env, args[0], args[1])
  } else if func.code() == native_query {
    perform_query(env, args[0])
  } else if func.code() == native_wait {
    perform_wait(args[0])
  } else if func.code() == native_browse {
    perform_browse(args[0])
  } else {
    raise EvalError::Cannot("function")
  }
}

///|
fn logic_order(
  result : Result[Bool, @action.ActionError],
) -> @value.Cell raise EvalError {
  match result {
    Ok(flag) => @value.Logic(flag)
    Err(_) => raise EvalError::Cannot("compare")
  }
}

///|
fn from_action(
  result : Result[@value.Cell, @action.ActionError],
) -> @value.Cell raise EvalError {
  match result {
    Ok(cell) => cell
    Err(error) => raise EvalError::Cannot(error.id())
  }
}

///|
fn infix_at(env : Env, series : @value.Series, index : Int) -> @value.Func? {
  if index >= series.length() {
    None
  } else {
    match series.item(index) {
      Some(@value.Sym(@value.Word, lexeme)) =>
        match quiet(env, lexeme) {
          Some(@value.Function(func)) if func.is_infix() => Some(func)
          _ => None
        }
      _ => None
    }
  }
}

///|
fn fetch(
  env : Env,
  series : @value.Series,
  index : Int,
  datatype : @value.Datatype,
  lexeme : @value.Lexeme,
) -> @value.Cell raise EvalError {
  match lexeme.binding() {
    @value.Bound(frame, slot) => defined(frame, slot, lexeme.spelling())
    @value.Unbound =>
      match env.user.find(lexeme.sym()) {
        Some(slot) => {
          series.set_item(
            index,
            @value.Sym(
              datatype,
              lexeme.with_binding(@value.Bound(env.user, slot)),
            ),
          )
          |> ignore
          defined(env.user, slot, lexeme.spelling())
        }
        None => raise EvalError::NoValue(lexeme.spelling())
      }
  }
}

///|
fn quiet(env : Env, lexeme : @value.Lexeme) -> @value.Cell? {
  match lexeme.binding() {
    @value.Bound(frame, slot) => frame.get(slot)
    @value.Unbound =>
      match env.user.find(lexeme.sym()) {
        Some(slot) => env.user.get(slot)
        None => None
      }
  }
}

///|
fn defined(
  frame : @value.Frame,
  slot : Int,
  spelling : String,
) -> @value.Cell raise EvalError {
  match frame.get(slot) {
    Some(cell) =>
      match cell {
        @value.Unset => raise EvalError::NoValue(spelling)
        _ => cell
      }
    None => raise EvalError::NoValue(spelling)
  }
}

///|
fn assign(
  env : Env,
  series : @value.Series,
  index : Int,
  lexeme : @value.Lexeme,
  value : @value.Cell,
) -> Unit raise EvalError {
  match lexeme.binding() {
    @value.Bound(frame, slot) => store(frame, slot, value)
    @value.Unbound => {
      let slot = env.user.ensure(lexeme.sym())
      series.set_item(
        index,
        @value.Sym(
          @value.SetWord,
          lexeme.with_binding(@value.Bound(env.user, slot)),
        ),
      )
      |> ignore
      store(env.user, slot, value)
    }
  }
}
