///|
priv struct Gather {
  mut stack : Array[@value.Series]
  mut held : @value.Cell?
  mut sink : @value.Series?
}

///|
let gather : Gather = { stack: [], held: None, sink: None, }

///|
/// Match a rule block against a series. Success does not require reaching the tail
/// unless the rules say `end`. `some` and `any` give back input when a later rule needs it.
/// A `collect` that is not `collect set` makes `parse` return that block.
fn perform_parse(
  env : Env,
  input : @value.Cell,
  rules : @value.Cell,
) -> @value.Cell raise EvalError {
  match (input, rules) {
    (@value.Seq(series, index), @value.Seq(rule_series, rule_index)) =>
      if rule_series.datatype() == @value.Block {
        let outer_stack = gather.stack
        let outer_held = gather.held
        let outer_sink = gather.sink
        gather.stack = []
        gather.held = None
        gather.sink = None
        errdefer {
          gather.stack = outer_stack
          gather.held = outer_held
          gather.sink = outer_sink
        }
        let outcome = match_rules(env, series, index, rule_series, rule_index)
        let result = match gather.held {
          Some(block) => block
          None =>
            match outcome {
              Some(_) => @value.Logic(true)
              None => @value.Logic(false)
            }
        }
        gather.stack = outer_stack
        gather.held = outer_held
        gather.sink = outer_sink
        result
      } else {
        raise EvalError::Cannot("parse")
      }
    _ => raise EvalError::Cannot("parse")
  }
}

///|
fn match_rules(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  index : Int,
) -> Int? raise EvalError {
  let mut start = index
  let mut found : Int? = None
  let mut cursor = index
  while found is None && cursor <= rules.length() {
    let bar = cursor == rules.length() || is_word(rules.item(cursor), "|")
    if bar {
      found = match_seq(env, input, pos, rules, start, cursor)
      start = cursor + 1
    }
    cursor = cursor + 1
  }
  found
}

///|
fn match_seq(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  if cursor >= end {
    Some(pos)
  } else {
    match rules.item(cursor) {
      Some(rule) =>
        if is_word(Some(rule), "some") || is_word(Some(rule), "any") {
          match rules.item(cursor + 1) {
            Some(item) =>
              repeat_rule(
                env,
                input,
                pos,
                item,
                is_word(Some(rule), "some"),
                rules,
                cursor + 2,
                end,
              )
            None => None
          }
        } else if is_word(Some(rule), "to") || is_word(Some(rule), "thru") {
          match rules.item(cursor + 1) {
            Some(item) =>
              match
                advance_to(env, input, pos, item, is_word(Some(rule), "thru")) {
                Some(next) =>
                  match_seq(env, input, next, rules, cursor + 2, end)
                None => None
              }
            None => raise EvalError::Cannot("parse")
          }
        } else if is_word(Some(rule), "skip") {
          if pos >= input.length() {
            None
          } else {
            match_seq(env, input, pos + 1, rules, cursor + 1, end)
          }
        } else if is_word(Some(rule), "copy") || is_word(Some(rule), "set") {
          capture(
            env,
            input,
            pos,
            rules,
            cursor,
            end,
            is_word(Some(rule), "copy"),
          )
        } else if is_kind(rule, @value.SetWord) {
          match rule {
            @value.Sym(_, lexeme) => {
              write_word(env, lexeme, @value.Seq(input, pos))
              match_seq(env, input, pos, rules, cursor + 1, end)
            }
            _ => None
          }
        } else if is_kind(rule, @value.GetWord) {
          let next = resume_at(env, input, rule)
          match_seq(env, input, next, rules, cursor + 1, end)
        } else if is_word(Some(rule), "break") {
          raise EvalError::Stopped(pos)
        } else if is_word(Some(rule), "fail") {
          None
        } else if is_word(Some(rule), "if") {
          when_true(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "into") {
          enter(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "remove") {
          cut_rule(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "change") {
          change_rule(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "insert") {
          insert_rule(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "collect") {
          collect_rule(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "keep") {
          keep_rule(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "opt") {
          counted_at(env, input, pos, rules, cursor + 1, end, 0L, 1L)
        } else if is_word(Some(rule), "not") {
          reject(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "ahead") || is_word(Some(rule), "and") {
          look_ahead(env, input, pos, rules, cursor, end)
        } else if is_word(Some(rule), "quote") {
          quoted(env, input, pos, rules, cursor, end)
        } else {
          match rule {
            @value.Seq(body, body_index) if body.datatype() == @value.Paren => {
              do_series(env, body, body_index) |> ignore
              match_seq(env, input, pos, rules, cursor + 1, end)
            }
            @value.Integer(n) => counted(env, input, pos, rules, cursor, end, n)
            @value.Sym(kind, _) if kind == @value.Word =>
              match_word(env, input, pos, rules, cursor, end, rule)
            _ =>
              match match_one(env, input, pos, rule) {
                Some(next) =>
                  match_seq(env, input, next, rules, cursor + 1, end)
                None => None
              }
          }
        }
      None => None
    }
  }
}

///|
fn repeat_rule(
  env : Env,
  input : @value.Series,
  pos : Int,
  item : @value.Cell,
  required : Bool,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  let stops : Array[Int] = [pos]
  let mut current = pos
  let mut running = true
  let mut halted : Int? = None
  while running && halted is None {
    let stepped = match_one(env, input, current, item) catch {
      EvalError::Stopped(at) => {
        halted = Some(at)
        None
      }
      error => raise error
    }
    match halted {
      Some(_) => ()
      None =>
        match stepped {
          Some(next) =>
            if next == current {
              running = false
            } else {
              stops.push(next)
              current = next
            }
          None => running = false
        }
    }
  }
  match halted {
    Some(at) => return match_seq(env, input, at, rules, cursor, end)
    None => ()
  }
  let mut found : Int? = None
  let mut index = stops.length() - 1
  let least = if required { 1 } else { 0 }
  while found is None && index >= least {
    found = match_seq(env, input, stops[index], rules, cursor, end)
    index = index - 1
  }
  found
}

///|
/// `n rule` repeats `rule` exactly `n` times. `min max rule` repeats it between the two counts.
fn counted(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
  n : Int64,
) -> Int? raise EvalError {
  if n < 0L {
    raise EvalError::Cannot("parse")
  }
  let least = n
  let mut most = n
  let mut rule_at = cursor + 1
  if rule_at < end {
    match rules.item(rule_at) {
      Some(@value.Integer(m)) => {
        most = m
        rule_at = rule_at + 1
      }
      _ => ()
    }
  }
  if most < least {
    raise EvalError::Cannot("parse")
  }
  counted_at(env, input, pos, rules, rule_at, end, least, most)
}

///|
fn counted_at(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  rule_at : Int,
  end : Int,
  least : Int64,
  most : Int64,
) -> Int? raise EvalError {
  if rule_at >= end {
    raise EvalError::Cannot("parse")
  }
  let width = rule_width(rules, rule_at, end)
  let stops : Array[Int] = [pos]
  let mut current = pos
  let mut times = 0L
  let mut running = true
  while running && times < most {
    match one_step(env, input, current, rules, rule_at, rule_at + width) {
      Some((next, _)) => {
        stops.push(next)
        times = times + 1L
        if next == current {
          running = false
        } else {
          current = next
        }
      }
      None => running = false
    }
  }
  if times < least {
    None
  } else {
    let mut index = stops.length() - 1
    let mut found : Int? = None
    while found is None && index >= 0 && index.to_int64() >= least {
      found = match_seq(env, input, stops[index], rules, rule_at + width, end)
      index = index - 1
    }
    found
  }
}

///|
fn reject(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  let rule_at = cursor + 1
  if rule_at >= end {
    raise EvalError::Cannot("parse")
  }
  let width = rule_width(rules, rule_at, end)
  match one_step(env, input, pos, rules, rule_at, rule_at + width) {
    Some(_) => None
    None => match_seq(env, input, pos, rules, rule_at + width, end)
  }
}

///|
fn look_ahead(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  let rule_at = cursor + 1
  if rule_at >= end {
    raise EvalError::Cannot("parse")
  }
  let width = rule_width(rules, rule_at, end)
  match one_step(env, input, pos, rules, rule_at, rule_at + width) {
    Some(_) => match_seq(env, input, pos, rules, rule_at + width, end)
    None => None
  }
}

///|
fn quoted(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  match one_step(env, input, pos, rules, cursor, end) {
    Some((next, next_cursor)) =>
      match_seq(env, input, next, rules, next_cursor, end)
    None => None
  }
}

///|
fn one_step(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  limit : Int,
) -> (Int, Int)? raise EvalError {
  if cursor >= limit {
    raise EvalError::Cannot("parse")
  }
  match rules.item(cursor) {
    Some(rule) =>
      if is_word(Some(rule), "skip") {
        if pos >= input.length() {
          None
        } else {
          Some((pos + 1, cursor + 1))
        }
      } else if is_word(Some(rule), "end") {
        if pos == input.length() {
          Some((pos, cursor + 1))
        } else {
          None
        }
      } else if is_word(Some(rule), "fail") {
        None
      } else if is_word(Some(rule), "quote") {
        match rules.item(cursor + 1) {
          Some(value) =>
            match quote_at(input, pos, value) {
              Some(next) => Some((next, cursor + 2))
              None => None
            }
          None => raise EvalError::Cannot("parse")
        }
      } else if is_word(Some(rule), "to") || is_word(Some(rule), "thru") {
        match rules.item(cursor + 1) {
          Some(target) =>
            match
              advance_to(env, input, pos, target, is_word(Some(rule), "thru")) {
              Some(next) => Some((next, cursor + 2))
              None => None
            }
          None => raise EvalError::Cannot("parse")
        }
      } else if is_command(rule) {
        raise EvalError::Cannot("parse")
      } else if is_paren(rule) {
        match rule {
          @value.Seq(body, body_index) => {
            do_series(env, body, body_index) |> ignore
            Some((pos, cursor + 1))
          }
          _ => None
        }
      } else {
        let value = fetched_rule(env, rule)
        match value {
          @value.Seq(series, index) if physical_equal(series, input) =>
            Some((clamped(input, index), cursor + 1))
          _ =>
            match match_one(env, input, pos, value) {
              Some(next) => Some((next, cursor + 1))
              None => None
            }
        }
      }
    None => raise EvalError::Cannot("parse")
  }
}

///|
fn rule_width(
  rules : @value.Series,
  cursor : Int,
  limit : Int,
) -> Int raise EvalError {
  match rules.item(cursor) {
    Some(rule) =>
      if is_word(Some(rule), "quote") ||
        is_word(Some(rule), "to") ||
        is_word(Some(rule), "thru") {
        if cursor + 1 >= limit {
          raise EvalError::Cannot("parse")
        }
        2
      } else {
        1
      }
    None => raise EvalError::Cannot("parse")
  }
}

///|
fn quote_at(input : @value.Series, pos : Int, value : @value.Cell) -> Int? {
  if input.datatype() == @value.String {
    match value {
      @value.Char(code) =>
        if input.code(pos) == Some(code) {
          Some(pos + 1)
        } else {
          None
        }
      @value.Seq(source, source_index) if source.datatype() == @value.String =>
        match_text(input, pos, source, source_index)
      _ => None
    }
  } else {
    match_value(input, pos, value)
  }
}

///|
fn cut_rule(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  let rule_at = cursor + 1
  if rule_at >= end {
    raise EvalError::Cannot("parse")
  }
  let width = rule_width(rules, rule_at, end)
  match one_step(env, input, pos, rules, rule_at, rule_at + width) {
    Some((next, _)) => {
      delete_span(input, pos, next)
      match_seq(env, input, pos, rules, rule_at + width, end)
    }
    None => None
  }
}

///|
fn change_rule(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  let rule_at = cursor + 1
  if rule_at >= end {
    raise EvalError::Cannot("parse")
  }
  let width = rule_width(rules, rule_at, end)
  match one_step(env, input, pos, rules, rule_at, rule_at + width) {
    Some((next, _)) => {
      let (value, only, after) = replacement(env, rules, rule_at + width, end)
      let placed = replace_span(input, pos, next, value, only)
      match_seq(env, input, placed, rules, after, end)
    }
    None => None
  }
}

///|
fn insert_rule(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  let (value, only, after) = replacement(env, rules, cursor + 1, end)
  let placed = replace_span(input, pos, pos, value, only)
  match_seq(env, input, placed, rules, after, end)
}

///|
fn replacement(
  env : Env,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> (@value.Cell, Bool, Int) raise EvalError {
  if cursor >= end {
    raise EvalError::Cannot("parse")
  }
  let mut at = cursor
  let mut only = false
  match rules.item(at) {
    Some(item) =>
      if is_word(Some(item), "only") {
        only = true
        at = at + 1
      }
    None => ()
  }
  match rules.item(at) {
    Some(@value.Seq(body, body_index)) if body.datatype() == @value.Paren =>
      (do_series(env, body, body_index), only, at + 1)
    Some(@value.Sym(kind, lexeme)) if kind == @value.Word =>
      match quiet(env, lexeme) {
        Some(value) =>
          match value {
            @value.Unset => raise EvalError::NoValue(lexeme.spelling())
            _ => (value, only, at + 1)
          }
        None => raise EvalError::NoValue(lexeme.spelling())
      }
    Some(value) => (value, only, at + 1)
    None => raise EvalError::Cannot("parse")
  }
}

///|
fn replace_span(
  input : @value.Series,
  begin : Int,
  end : Int,
  value : @value.Cell,
  only : Bool,
) -> Int raise EvalError {
  delete_span(input, begin, end)
  if input.datatype() == @value.String {
    insert_text(input, begin, value)
  } else {
    insert_items(input, begin, value, only)
  }
}

///|
fn delete_span(input : @value.Series, begin : Int, end : Int) -> Unit {
  let mut index = if end > begin { end } else { begin }
  if input.datatype() == @value.String {
    while index > begin {
      index = index - 1
      input.remove_code(index) |> ignore
    }
  } else {
    while index > begin {
      index = index - 1
      input.remove_item(index) |> ignore
    }
  }
}

///|
fn insert_text(
  input : @value.Series,
  begin : Int,
  value : @value.Cell,
) -> Int raise EvalError {
  let codes = match value {
    @value.Char(code) => [code]
    @value.Seq(source, source_index) if source.datatype() == @value.String => {
      let found : Array[Int] = []
      for index in source_index..<source.length() {
        match source.code(index) {
          Some(code) => found.push(code)
          None => ()
        }
      }
      found
    }
    _ => raise EvalError::Cannot("parse")
  }
  let mut at = begin
  for code in codes {
    input.insert_code(at, code) |> ignore
    at = at + 1
  }
  at
}

///|
fn insert_items(
  input : @value.Series,
  begin : Int,
  value : @value.Cell,
  only : Bool,
) -> Int {
  let items = match value {
    @value.Seq(source, source_index) if !only &&
      (source.datatype() == @value.Block || source.datatype() == @value.Paren) => {
      let found : Array[@value.Cell] = []
      for index in source_index..<source.length() {
        match source.item(index) {
          Some(item) => found.push(as_word_value(item))
          None => ()
        }
      }
      found
    }
    _ => [as_word_value(value)]
  }
  let mut at = begin
  for item in items {
    input.insert_item(at, item.snapshot()) |> ignore
    at = at + 1
  }
  at
}

///|
fn as_word_value(value : @value.Cell) -> @value.Cell {
  match value {
    @value.Sym(@value.LitWord, lexeme) => @value.Sym(@value.Word, lexeme)
    _ => value
  }
}

///|
fn collect_rule(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  let mut at = cursor + 1
  let mut target : @value.Lexeme? = None
  if is_word(rules.item(at), "set") {
    target = Some(capture_name(rules.item(at + 1)))
    at = at + 2
  }
  let stop = rule_extent(env, rules, at, end)
  open_collect(env, target)
  let matched = match_seq(env, input, pos, rules, at, stop)
  close_collect()
  match matched {
    Some(next) => match_seq(env, input, next, rules, stop, end)
    None => None
  }
}

///|
fn keep_rule(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  let mut at = cursor + 1
  let mut pick = false
  if is_word(rules.item(at), "pick") {
    pick = true
    at = at + 1
  }
  match rules.item(at) {
    Some(@value.Seq(body, body_index)) if body.datatype() == @value.Paren => {
      let value = do_series(env, body, body_index)
      keep_value(value)
      match_seq(env, input, pos, rules, at + 1, end)
    }
    _ => {
      let stop = rule_extent(env, rules, at, end)
      match match_seq(env, input, pos, rules, at, stop) {
        Some(next) => {
          keep_span(input, pos, next, pick)
          match_seq(env, input, next, rules, stop, end)
        }
        None => None
      }
    }
  }
}

///|
fn open_collect(env : Env, target : @value.Lexeme?) -> Unit {
  let block = @value.Series::block()
  match target {
    Some(lexeme) => {
      write_word(env, lexeme, @value.Seq(block, 0))
      gather.stack.push(block)
    }
    None =>
      if gather.stack.length() == 0 {
        match gather.sink {
          None => {
            gather.held = Some(@value.Seq(block, 0))
            gather.sink = Some(block)
            gather.stack.push(block)
          }
          Some(parent) => {
            parent.push_item(@value.Seq(block, 0)) |> ignore
            gather.stack.push(block)
          }
        }
      } else {
        let parent = gather.stack[gather.stack.length() - 1]
        parent.push_item(@value.Seq(block, 0)) |> ignore
        gather.stack.push(block)
      }
  }
}

///|
fn close_collect() -> Unit {
  if gather.stack.length() > 0 {
    gather.stack.pop() |> ignore
  }
}

///|
fn keep_value(value : @value.Cell) -> Unit raise EvalError {
  let block = keep_block()
  block.push_item(value.snapshot()) |> ignore
}

///|
fn keep_span(
  input : @value.Series,
  begin : Int,
  end : Int,
  pick : Bool,
) -> Unit raise EvalError {
  let count = if end > begin { end - begin } else { 0 }
  if count == 0 {
    ()
  } else {
    let block = keep_block()
    if input.datatype() == @value.String {
      if pick && count > 1 {
        for index in begin..<end {
          match input.code(index) {
            Some(code) => block.push_item(@value.Char(code)) |> ignore
            None => ()
          }
        }
      } else if count == 1 {
        match input.code(begin) {
          Some(code) => block.push_item(@value.Char(code)) |> ignore
          None => ()
        }
      } else {
        block.push_item(copy_span(input, begin, end)) |> ignore
      }
    } else if pick && count > 1 {
      for index in begin..<end {
        match input.item(index) {
          Some(item) => block.push_item(item.snapshot()) |> ignore
          None => ()
        }
      }
    } else if count == 1 {
      match input.item(begin) {
        Some(item) => block.push_item(item.snapshot()) |> ignore
        None => ()
      }
    } else {
      block.push_item(copy_span(input, begin, end)) |> ignore
    }
  }
}

///|
fn keep_block() -> @value.Series raise EvalError {
  let length = gather.stack.length()
  if length == 0 {
    raise EvalError::Cannot("parse")
  }
  gather.stack[length - 1]
}

///|
fn match_word(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
  rule : @value.Cell,
) -> Int? raise EvalError {
  if is_word(Some(rule), "end") {
    match match_one(env, input, pos, rule) {
      Some(next) => match_seq(env, input, next, rules, cursor + 1, end)
      None => None
    }
  } else {
    let value = fetched_rule(env, rule)
    match value {
      @value.Integer(n) => counted(env, input, pos, rules, cursor, end, n)
      @value.Seq(series, index) if physical_equal(series, input) =>
        match_seq(env, input, clamped(input, index), rules, cursor + 1, end)
      _ =>
        match match_one(env, input, pos, value) {
          Some(next) => match_seq(env, input, next, rules, cursor + 1, end)
          None => None
        }
    }
  }
}

///|
fn fetched_rule(env : Env, rule : @value.Cell) -> @value.Cell raise EvalError {
  match rule {
    @value.Sym(kind, lexeme) if kind == @value.Word =>
      match quiet(env, lexeme) {
        Some(value) =>
          match value {
            @value.Unset => raise EvalError::NoValue(lexeme.spelling())
            _ => value
          }
        None => raise EvalError::NoValue(lexeme.spelling())
      }
    _ => rule
  }
}

///|
fn clamped(input : @value.Series, index : Int) -> Int {
  if index < 0 {
    0
  } else if index > input.length() {
    input.length()
  } else {
    index
  }
}

///|
fn rule_extent(
  env : Env,
  rules : @value.Series,
  cursor : Int,
  limit : Int,
) -> Int raise EvalError {
  if cursor >= limit {
    raise EvalError::Cannot("parse")
  }
  match rules.item(cursor) {
    Some(rule) =>
      if is_word(Some(rule), "some") ||
        is_word(Some(rule), "any") ||
        is_word(Some(rule), "opt") ||
        is_word(Some(rule), "not") ||
        is_word(Some(rule), "ahead") ||
        is_word(Some(rule), "and") ||
        is_word(Some(rule), "remove") {
        rule_extent(env, rules, cursor + 1, limit)
      } else if is_word(Some(rule), "keep") {
        let at = if is_word(rules.item(cursor + 1), "pick") {
          cursor + 2
        } else {
          cursor + 1
        }
        rule_extent(env, rules, at, limit)
      } else if is_word(Some(rule), "collect") {
        let at = if is_word(rules.item(cursor + 1), "set") {
          cursor + 3
        } else {
          cursor + 1
        }
        rule_extent(env, rules, at, limit)
      } else if is_word(Some(rule), "change") {
        value_extent(rules, rule_extent(env, rules, cursor + 1, limit), limit)
      } else if is_word(Some(rule), "insert") {
        value_extent(rules, cursor + 1, limit)
      } else if is_word(Some(rule), "copy") || is_word(Some(rule), "set") {
        rule_extent(env, rules, cursor + 2, limit)
      } else if is_word(Some(rule), "quote") ||
        is_word(Some(rule), "to") ||
        is_word(Some(rule), "thru") ||
        is_word(Some(rule), "if") ||
        is_word(Some(rule), "into") {
        if cursor + 1 >= limit {
          raise EvalError::Cannot("parse")
        }
        cursor + 2
      } else {
        match rule {
          @value.Integer(_) => {
            let at = match rules.item(cursor + 1) {
              Some(@value.Integer(_)) => cursor + 2
              _ => cursor + 1
            }
            rule_extent(env, rules, at, limit)
          }
          @value.Sym(kind, lexeme) if kind == @value.Word =>
            match quiet(env, lexeme) {
              Some(@value.Integer(_)) => {
                let at = match rules.item(cursor + 1) {
                  Some(@value.Integer(_)) => cursor + 2
                  _ => cursor + 1
                }
                rule_extent(env, rules, at, limit)
              }
              _ => cursor + 1
            }
          _ => cursor + 1
        }
      }
    None => raise EvalError::Cannot("parse")
  }
}

///|
fn value_extent(
  rules : @value.Series,
  cursor : Int,
  limit : Int,
) -> Int raise EvalError {
  if cursor >= limit {
    raise EvalError::Cannot("parse")
  }
  let at = if is_word(rules.item(cursor), "only") { cursor + 1 } else { cursor }
  if at >= limit {
    raise EvalError::Cannot("parse")
  }
  at + 1
}

///|
fn is_command(cell : @value.Cell) -> Bool {
  is_word(Some(cell), "some") ||
  is_word(Some(cell), "any") ||
  is_word(Some(cell), "copy") ||
  is_word(Some(cell), "set") ||
  is_word(Some(cell), "into") ||
  is_word(Some(cell), "break") ||
  is_word(Some(cell), "if") ||
  is_word(Some(cell), "opt") ||
  is_word(Some(cell), "not") ||
  is_word(Some(cell), "ahead") ||
  is_word(Some(cell), "and") ||
  is_word(Some(cell), "remove") ||
  is_word(Some(cell), "change") ||
  is_word(Some(cell), "insert") ||
  is_word(Some(cell), "collect") ||
  is_word(Some(cell), "keep")
}

///|
fn match_one(
  env : Env,
  input : @value.Series,
  pos : Int,
  rule : @value.Cell,
) -> Int? raise EvalError {
  if is_word(Some(rule), "end") {
    if pos == input.length() {
      Some(pos)
    } else {
      None
    }
  } else {
    match rule {
      @value.Bitset(bits) =>
        if input.datatype() == @value.String {
          match input.code(pos) {
            Some(code) => if bits.has(code) { Some(pos + 1) } else { None }
            None => None
          }
        } else {
          None
        }
      @value.Char(code) =>
        if input.datatype() == @value.String && input.code(pos) == Some(code) {
          Some(pos + 1)
        } else {
          None
        }
      @value.Type(datatype) =>
        if input.datatype() == @value.String ||
          input.datatype() == @value.Binary {
          raise EvalError::Cannot("parse")
        } else {
          match input.item(pos) {
            Some(item) =>
              if item.datatype() == datatype {
                Some(pos + 1)
              } else {
                None
              }
            None => None
          }
        }
      @value.Seq(source, source_index) =>
        if source.datatype() == @value.Block {
          match_rules(env, input, pos, source, source_index)
        } else if source.datatype() == @value.String &&
          input.datatype() == @value.String {
          match_text(input, pos, source, source_index)
        } else {
          match_value(input, pos, rule)
        }
      _ => match_value(input, pos, rule)
    }
  }
}

///|
/// `to` stops on the target. `thru` stops just past it.
/// An integer is an absolute index, one-based, and may move backward.
fn advance_to(
  env : Env,
  input : @value.Series,
  pos : Int,
  raw : @value.Cell,
  thru : Bool,
) -> Int? raise EvalError {
  let target = resolve_target(env, raw)
  if is_word(Some(target), "end") {
    Some(input.length())
  } else {
    match target {
      @value.Integer(n) => absolute_index(input.length(), n, thru)
      @value.Seq(source, source_index) if source.datatype() == @value.Block =>
        scan_block(env, input, pos, source, source_index, thru)
      _ => find_target(input, pos, target, thru)
    }
  }
}

///|
fn absolute_index(length : Int, n : Int64, thru : Bool) -> Int? {
  let raw = if thru { n } else { n - 1L }
  if raw < 0L {
    None
  } else if raw >= length.to_int64() {
    Some(length)
  } else {
    Some(raw.to_int())
  }
}

///|
fn find_target(
  input : @value.Series,
  pos : Int,
  target : @value.Cell,
  thru : Bool,
) -> Int? raise EvalError {
  if input.datatype() == @value.String {
    match target {
      @value.Char(_) | @value.Bitset(_) => scan_here(input, pos, target, thru)
      @value.Seq(source, _) if source.datatype() == @value.String =>
        scan_here(input, pos, target, thru)
      _ => raise EvalError::Cannot("parse")
    }
  } else if is_block(input) {
    match target {
      @value.Type(datatype) => scan_type(input, pos, datatype, thru)
      _ => scan_here(input, pos, target, thru)
    }
  } else {
    raise EvalError::Cannot("parse")
  }
}

///|
fn scan_here(
  input : @value.Series,
  pos : Int,
  target : @value.Cell,
  thru : Bool,
) -> Int? {
  let mut at = pos
  let mut found : Int? = None
  while found is None && at <= input.length() {
    match hit_at(input, at, target) {
      Some(next) => found = Some(if thru { next } else { at })
      None => at = at + 1
    }
  }
  found
}

///|
fn scan_type(
  input : @value.Series,
  pos : Int,
  datatype : @value.Datatype,
  thru : Bool,
) -> Int? {
  let mut at = pos
  let mut found : Int? = None
  while found is None && at < input.length() {
    match input.item(at) {
      Some(item) =>
        if item.datatype() == datatype {
          found = Some(if thru { at + 1 } else { at })
        } else {
          at = at + 1
        }
      None => at = at + 1
    }
  }
  found
}

///|
fn scan_block(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  index : Int,
  thru : Bool,
) -> Int? raise EvalError {
  let targets = block_targets(env, rules, index)
  let mut at = pos
  let mut found : Int? = None
  while found is None && at <= input.length() {
    let mut choice = 0
    while found is None && choice < targets.length() {
      match hit_at(input, at, targets[choice]) {
        Some(next) => found = Some(if thru { next } else { at })
        None => choice = choice + 1
      }
    }
    at = at + 1
  }
  found
}

///|
/// One value between bars. `to [{ab} {c}]` is a bad rule; `to [{ab} | {c}]` is not.
fn block_targets(
  env : Env,
  rules : @value.Series,
  index : Int,
) -> Array[@value.Cell] raise EvalError {
  let targets : Array[@value.Cell] = []
  let mut cursor = index
  let mut ready = false
  while cursor < rules.length() {
    match rules.item(cursor) {
      Some(item) =>
        if is_word(Some(item), "|") {
          if !ready {
            raise EvalError::Cannot("parse")
          }
          ready = false
        } else if ready {
          raise EvalError::Cannot("parse")
        } else {
          targets.push(resolve_target(env, item))
          ready = true
        }
      None => ()
    }
    cursor = cursor + 1
  }
  if !ready {
    raise EvalError::Cannot("parse")
  }
  targets
}

///|
fn hit_at(input : @value.Series, pos : Int, target : @value.Cell) -> Int? {
  if input.datatype() == @value.String {
    match target {
      @value.Char(code) =>
        if input.code(pos) == Some(code) {
          Some(pos + 1)
        } else {
          None
        }
      @value.Bitset(bits) =>
        match input.code(pos) {
          Some(code) => if bits.has(code) { Some(pos + 1) } else { None }
          None => None
        }
      @value.Seq(source, source_index) if source.datatype() == @value.String =>
        match_text(input, pos, source, source_index)
      @value.Integer(n) =>
        match input.code(pos) {
          Some(code) =>
            if n >= 0L && n == code.to_int64() {
              Some(pos + 1)
            } else {
              None
            }
          None => None
        }
      _ => None
    }
  } else {
    match target {
      @value.Type(datatype) =>
        match input.item(pos) {
          Some(item) =>
            if item.datatype() == datatype {
              Some(pos + 1)
            } else {
              None
            }
          None => None
        }
      _ =>
        match input.item(pos) {
          Some(item) => if item.equal(target) { Some(pos + 1) } else { None }
          None => None
        }
    }
  }
}

///|
fn resolve_target(env : Env, cell : @value.Cell) -> @value.Cell raise EvalError {
  match cell {
    @value.Sym(_, lexeme) =>
      if lexeme.spelling().to_lower() == "end" {
        cell
      } else if bad_target(lexeme.spelling().to_lower()) {
        raise EvalError::Cannot("parse")
      } else {
        match quiet(env, lexeme) {
          Some(value) =>
            match value {
              @value.Unset => raise EvalError::Cannot("parse")
              _ => value
            }
          None => raise EvalError::Cannot("parse")
        }
      }
    _ => cell
  }
}

///|
fn bad_target(spelling : String) -> Bool {
  spelling == "some" ||
  spelling == "any" ||
  spelling == "to" ||
  spelling == "thru" ||
  spelling == "skip" ||
  spelling == "copy" ||
  spelling == "set" ||
  spelling == "into" ||
  spelling == "break" ||
  spelling == "fail" ||
  spelling == "if" ||
  spelling == "opt" ||
  spelling == "not" ||
  spelling == "ahead" ||
  spelling == "and" ||
  spelling == "quote" ||
  spelling == "remove" ||
  spelling == "change" ||
  spelling == "insert" ||
  spelling == "collect" ||
  spelling == "keep" ||
  spelling == "|"
}

///|
fn match_text(
  input : @value.Series,
  pos : Int,
  source : @value.Series,
  source_index : Int,
) -> Int? {
  let len = source.length() - source_index
  if pos + len > input.length() {
    None
  } else {
    let mut ok = true
    for offset in 0..<len {
      if input.code(pos + offset) != source.code(source_index + offset) {
        ok = false
      }
    }
    if ok {
      Some(pos + len)
    } else {
      None
    }
  }
}

///|
fn match_value(input : @value.Series, pos : Int, rule : @value.Cell) -> Int? {
  match input.item(pos) {
    Some(item) => if item.equal(rule) { Some(pos + 1) } else { None }
    None => None
  }
}

///|
fn when_true(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  match rules.item(cursor + 1) {
    Some(@value.Seq(body, body_index)) if body.datatype() == @value.Paren =>
      if is_false(do_series(env, body, body_index)) {
        None
      } else {
        match_seq(env, input, pos, rules, cursor + 2, end)
      }
    _ => raise EvalError::Cannot("parse")
  }
}

///|
fn enter(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? raise EvalError {
  match rules.item(cursor + 1) {
    Some(@value.Seq(sub, sub_index)) if sub.datatype() == @value.Block =>
      match input.item(pos) {
        Some(@value.Seq(nested, nested_index)) =>
          match match_rules(env, nested, nested_index, sub, sub_index) {
            Some(done) =>
              if done == nested.length() {
                match_seq(env, input, pos + 1, rules, cursor + 2, end)
              } else {
                None
              }
            None => None
          }
        _ => None
      }
    Some(_) => raise EvalError::Cannot("parse")
    None => raise EvalError::Cannot("parse")
  }
}

///|
fn capture(
  env : Env,
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
  copying : Bool,
) -> Int? raise EvalError {
  if cursor + 1 >= end {
    raise EvalError::Cannot("parse")
  }
  let lexeme = capture_name(rules.item(cursor + 1))
  let at = cursor + 2
  match rules.item(at) {
    Some(item) =>
      if is_word(Some(item), "some") || is_word(Some(item), "any") {
        match rules.item(at + 1) {
          Some(repeated) => {
            let stops = repeat_stops(env, input, pos, repeated)
            let least = if is_word(Some(item), "some") { 1 } else { 0 }
            let mut index = stops.length() - 1
            let mut found : Int? = None
            while found is None && index >= least {
              let stop = stops[index]
              write_capture(env, lexeme, input, pos, stop, copying)
              found = match_seq(env, input, stop, rules, at + 2, end)
              index = index - 1
            }
            found
          }
          None => raise EvalError::Cannot("parse")
        }
      } else if is_word(Some(item), "to") || is_word(Some(item), "thru") {
        match rules.item(at + 1) {
          Some(target) =>
            match
              advance_to(env, input, pos, target, is_word(Some(item), "thru")) {
              Some(next) => {
                write_capture(env, lexeme, input, pos, next, copying)
                match_seq(env, input, next, rules, at + 2, end)
              }
              None => None
            }
          None => raise EvalError::Cannot("parse")
        }
      } else if is_word(Some(item), "skip") {
        if pos >= input.length() {
          None
        } else {
          write_capture(env, lexeme, input, pos, pos + 1, copying)
          match_seq(env, input, pos + 1, rules, at + 1, end)
        }
      } else {
        match match_one(env, input, pos, item) {
          Some(next) => {
            write_capture(env, lexeme, input, pos, next, copying)
            match_seq(env, input, next, rules, at + 1, end)
          }
          None => None
        }
      }
    None => raise EvalError::Cannot("parse")
  }
}

///|
fn repeat_stops(
  env : Env,
  input : @value.Series,
  pos : Int,
  item : @value.Cell,
) -> Array[Int] raise EvalError {
  let stops : Array[Int] = [pos]
  let mut current = pos
  let mut running = true
  while running {
    match match_one(env, input, current, item) {
      Some(next) =>
        if next == current {
          running = false
        } else {
          stops.push(next)
          current = next
        }
      None => running = false
    }
  }
  stops
}

///|
fn write_capture(
  env : Env,
  lexeme : @value.Lexeme,
  input : @value.Series,
  begin : Int,
  end : Int,
  copying : Bool,
) -> Unit {
  let value = if copying {
    copy_span(input, begin, end)
  } else {
    taken_value(input, begin, end)
  }
  write_word(env, lexeme, value)
}

///|
fn copy_span(input : @value.Series, begin : Int, end : Int) -> @value.Cell {
  let from = begin
  let until = if end > begin { end } else { begin }
  if input.datatype() == @value.String {
    let series = @value.Series::text()
    for index in from..<until {
      match input.code(index) {
        Some(code) => series.push_code(code) |> ignore
        None => ()
      }
    }
    @value.Seq(series, 0)
  } else {
    let series = @value.Series::block()
    for index in from..<until {
      match input.item(index) {
        Some(item) => series.push_item(item.snapshot()) |> ignore
        None => ()
      }
    }
    @value.Seq(series, 0)
  }
}

///|
fn taken_value(input : @value.Series, begin : Int, end : Int) -> @value.Cell {
  if end <= begin {
    @value.None
  } else if input.datatype() == @value.String {
    match input.code(begin) {
      Some(code) => @value.Char(code)
      None => @value.None
    }
  } else {
    match input.item(begin) {
      Some(item) => item
      None => @value.None
    }
  }
}

///|
fn capture_name(cell : @value.Cell?) -> @value.Lexeme raise EvalError {
  match cell {
    Some(@value.Sym(kind, lexeme)) if kind == @value.Word ||
      kind == @value.SetWord =>
      if bad_target(lexeme.spelling().to_lower()) {
        raise EvalError::Cannot("parse")
      } else {
        lexeme
      }
    _ => raise EvalError::Cannot("parse")
  }
}

///|
fn resume_at(
  env : Env,
  input : @value.Series,
  rule : @value.Cell,
) -> Int raise EvalError {
  match rule {
    @value.Sym(_, lexeme) =>
      match slot_value(env, lexeme) {
        Some(@value.Seq(series, index)) =>
          if physical_equal(series, input) {
            if index < 0 {
              0
            } else if index > input.length() {
              input.length()
            } else {
              index
            }
          } else {
            raise EvalError::Cannot("parse")
          }
        _ => raise EvalError::Cannot("parse")
      }
    _ => raise EvalError::Cannot("parse")
  }
}

///|
fn is_kind(cell : @value.Cell, kind : @value.Datatype) -> Bool {
  match cell {
    @value.Sym(datatype, _) => datatype == kind
    _ => false
  }
}

///|
fn is_paren(cell : @value.Cell) -> Bool {
  match cell {
    @value.Seq(body, _) => body.datatype() == @value.Paren
    _ => false
  }
}

///|
fn is_block(series : @value.Series) -> Bool {
  series.datatype() == @value.Block ||
  series.datatype() == @value.Paren ||
  series.datatype() == @value.Path ||
  series.datatype() == @value.SetPath
}

///|
fn is_word(cell : @value.Cell?, spelling : String) -> Bool {
  match cell {
    Some(@value.Sym(_, lexeme)) => lexeme.spelling().to_lower() == spelling
    _ => false
  }
}
