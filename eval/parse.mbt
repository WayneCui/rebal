///|
/// Match a rule block against a series. Success does not require reaching the tail
/// unless the rules say `end`. `some` and `any` give back input when a later rule needs it.
fn perform_parse(
  env : Env,
  input : @value.Cell,
  rules : @value.Cell,
) -> @value.Cell raise EvalError {
  match (input, rules) {
    (@value.Seq(series, index), @value.Seq(rule_series, rule_index)) =>
      if rule_series.datatype() == @value.Block {
        match match_rules(env, series, index, rule_series, rule_index) {
          Some(_) => @value.Logic(true)
          None => @value.Logic(false)
        }
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
        } else {
          match match_one(env, input, pos, rule) {
            Some(next) => match_seq(env, input, next, rules, cursor + 1, end)
            None => None
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
