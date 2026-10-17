///|
/// Match a rule block against a series. Success does not require reaching the tail
/// unless the rules say `end`. `some` and `any` give back input when a later rule needs it.
fn perform_parse(
  input : @value.Cell,
  rules : @value.Cell,
) -> @value.Cell raise EvalError {
  match (input, rules) {
    (@value.Seq(series, index), @value.Seq(rule_series, rule_index)) =>
      if rule_series.datatype() == @value.Block {
        match match_rules(series, index, rule_series, rule_index) {
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
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  index : Int,
) -> Int? {
  let mut start = index
  let mut found : Int? = None
  let mut cursor = index
  while found is None && cursor <= rules.length() {
    let bar = cursor == rules.length() || is_word(rules.item(cursor), "|")
    if bar {
      found = match_seq(input, pos, rules, start, cursor)
      start = cursor + 1
    }
    cursor = cursor + 1
  }
  found
}

///|
fn match_seq(
  input : @value.Series,
  pos : Int,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? {
  if cursor >= end {
    Some(pos)
  } else {
    match rules.item(cursor) {
      Some(rule) =>
        if is_word(Some(rule), "some") || is_word(Some(rule), "any") {
          match rules.item(cursor + 1) {
            Some(item) =>
              repeat_rule(
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
        } else {
          match match_one(input, pos, rule) {
            Some(next) => match_seq(input, next, rules, cursor + 1, end)
            None => None
          }
        }
      None => None
    }
  }
}

///|
fn repeat_rule(
  input : @value.Series,
  pos : Int,
  item : @value.Cell,
  required : Bool,
  rules : @value.Series,
  cursor : Int,
  end : Int,
) -> Int? {
  let stops : Array[Int] = [pos]
  let mut current = pos
  let mut running = true
  while running {
    match match_one(input, current, item) {
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
    found = match_seq(input, stops[index], rules, cursor, end)
    index = index - 1
  }
  found
}

///|
fn match_one(input : @value.Series, pos : Int, rule : @value.Cell) -> Int? {
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
          match_rules(input, pos, source, source_index)
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
fn is_word(cell : @value.Cell?, spelling : String) -> Bool {
  match cell {
    Some(@value.Sym(_, lexeme)) => lexeme.spelling() == spelling
    _ => false
  }
}
