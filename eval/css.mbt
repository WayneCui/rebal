///|
/// CSS tokens, as in codec-css.reb. A computed `keep` is held until the
/// whole collection finishes, so a number or a run of whitespace shows up
/// after the tokens that were kept from the input itself.
fn decode_css(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      css_block(css_tokenize(string_utf8(value, bytes_from(series, index))))
    @value.Seq(series, index) if series.datatype() == @value.File =>
      decode_css(binary_cell(read_binary(text_from(series, index))))
    _ => raise EvalError::Caused("expect-arg", "decode")
  }
}

///|
/// Minify a token block. The codec accepts only a block. Comparisons of
/// `ms`, `black`, `white`, and `and` ignore case, because this parse is
/// not case-sensitive.
fn encode_css(value : @value.Cell) -> @value.Cell raise EvalError {
  match value {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      text_series(css_minify(css_cells(series, index)))
    _ => raise EvalError::Caused("expect-arg", "encode")
  }
}

///|
fn css_block(items : Array[@value.Cell]) -> @value.Cell {
  let block = @value.Series::block()
  for item in items {
    block.push_item(item) |> ignore
  }
  @value.Seq(block, 0)
}

///|
fn css_cells(series : @value.Series, index : Int) -> Array[@value.Cell] {
  let items : Array[@value.Cell] = []
  let mut cursor = if index < 0 { 0 } else { index }
  while cursor < series.length() {
    match series.item(cursor) {
      Some(item) => items.push(item)
      None => ()
    }
    cursor = cursor + 1
  }
  items
}

///|
fn css_tokenize(text : String) -> Array[@value.Cell] {
  let codes = css_codes(text)
  let now : Array[@value.Cell] = []
  let later : Array[@value.Cell] = []
  let mut at = css_skip_ws(codes, 0)
  while at < codes.length() {
    match css_comment(codes, at) {
      Some(next) => at = next
      None =>
        match css_kept(codes, at) {
          Some(next) => {
            now.push(css_piece(codes, at, next))
            at = next
          }
          None =>
            match css_number(codes, at) {
              Some((number_end, unit_end)) => {
                if unit_end > number_end {
                  now.push(css_piece(codes, number_end, unit_end))
                }
                later.push(css_number_cell(css_span(codes, at, number_end)))
                at = unit_end
              }
              None =>
                if css_ws(codes[at]) {
                  at = css_skip_ws(codes, at)
                  later.push(@value.Char(' '.to_int()))
                } else {
                  now.push(@value.Char(codes[at]))
                  at = at + 1
                }
            }
        }
    }
  }
  for item in later {
    now.push(item)
  }
  now
}

///|
fn css_codes(text : String) -> Array[Int] {
  let codes : Array[Int] = []
  for char in text {
    codes.push(char.to_int())
  }
  codes
}

///|
fn css_piece(codes : Array[Int], start : Int, end : Int) -> @value.Cell {
  if end - start == 1 {
    @value.Char(codes[start])
  } else {
    text_series(css_span(codes, start, end))
  }
}

///|
fn css_span(codes : Array[Int], start : Int, end : Int) -> String {
  let buf = StringBuilder()
  for index in start..<end {
    buf.write_char(codes[index].to_char().unwrap())
  }
  buf.to_string()
}

///|
fn css_number_cell(text : String) -> @value.Cell {
  let mut negative = false
  let mut dotted = false
  let mut whole = 0L
  let mut fraction = 0.0
  let mut place = 0.1
  let mut signed = false
  for char in text {
    if !signed && (char == '+' || char == '-') {
      negative = char == '-'
      signed = true
    } else if char == '.' {
      dotted = true
      signed = true
    } else {
      signed = true
      let digit = char.to_int() - '0'.to_int()
      if dotted {
        fraction = fraction + digit.to_double() * place
        place = place * 0.1
      } else {
        whole = whole * 10L + digit.to_int64()
      }
    }
  }
  if dotted {
    let magnitude = whole.to_double() + fraction
    if negative {
      @value.Decimal(-magnitude)
    } else {
      @value.Decimal(magnitude)
    }
  } else if negative {
    @value.Integer(-whole)
  } else {
    @value.Integer(whole)
  }
}

///|
fn css_kept(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() {
    return None
  }
  let code = codes[at]
  if css_token_char(code) || css_combinator(code) {
    return Some(at + 1)
  }
  match css_string(codes, at) {
    Some(next) => Some(next)
    None =>
      match css_type_selector(codes, at) {
        Some(next) => Some(next)
        None =>
          match css_universal(codes, at) {
            Some(next) => Some(next)
            None =>
              match css_hash(codes, at) {
                Some(next) => Some(next)
                None =>
                  match css_class(codes, at) {
                    Some(next) => Some(next)
                    None =>
                      match css_attrib(codes, at) {
                        Some(next) => Some(next)
                        None => css_ident(codes, at)
                      }
                  }
              }
          }
      }
  }
}

///|
fn css_token_char(code : Int) -> Bool {
  code == '{'.to_int() ||
  code == '}'.to_int() ||
  code == ':'.to_int() ||
  code == '@'.to_int() ||
  code == ';'.to_int() ||
  code == '('.to_int() ||
  code == ')'.to_int() ||
  code == ','.to_int()
}

///|
fn css_combinator(code : Int) -> Bool {
  code == '+'.to_int() || code == '>'.to_int() || code == '~'.to_int()
}

///|
fn css_string(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() {
    return None
  }
  let quote = codes[at]
  if quote != '"'.to_int() && quote != '\''.to_int() {
    return None
  }
  let mut cursor = at + 1
  let mut held = false
  let mut closed = false
  while cursor < codes.length() && !closed {
    if codes[cursor] == quote {
      cursor = cursor + 1
      closed = true
    } else {
      match css_string_char(codes, cursor) {
        Some(next) => {
          held = true
          cursor = next
        }
        None => closed = true
      }
    }
  }
  if (closed && cursor > at + 1) || held {
    Some(cursor)
  } else {
    None
  }
}

///|
fn css_string_char(codes : Array[Int], at : Int) -> Int? {
  if codes[at] == '\\'.to_int() {
    match css_newline(codes, at + 1) {
      Some(next) => Some(next)
      None => css_escape(codes, at)
    }
  } else if css_string_plain(codes[at]) {
    Some(at + 1)
  } else {
    None
  }
}

///|
fn css_string_plain(code : Int) -> Bool {
  code != '"'.to_int() &&
  code != '\n'.to_int() &&
  code != '\r'.to_int() &&
  code != 12
}

///|
fn css_type_selector(codes : Array[Int], at : Int) -> Int? {
  match css_namespace(codes, at) {
    Some(next) => css_ident(codes, next)
    None => css_ident(codes, at)
  }
}

///|
fn css_universal(codes : Array[Int], at : Int) -> Int? {
  match css_namespace(codes, at) {
    Some(next) =>
      if next < codes.length() && codes[next] == '*'.to_int() {
        Some(next + 1)
      } else {
        None
      }
    None =>
      if at < codes.length() && codes[at] == '*'.to_int() {
        Some(at + 1)
      } else {
        None
      }
  }
}

///|
fn css_namespace(codes : Array[Int], at : Int) -> Int? {
  match css_ident(codes, at) {
    Some(next) if next < codes.length() && codes[next] == '|'.to_int() =>
      Some(next + 1)
    _ =>
      if at < codes.length() &&
        codes[at] == '*'.to_int() &&
        at + 1 < codes.length() &&
        codes[at + 1] == '|'.to_int() {
        Some(at + 2)
      } else if at < codes.length() && codes[at] == '|'.to_int() {
        Some(at + 1)
      } else {
        None
      }
  }
}

///|
fn css_hash(codes : Array[Int], at : Int) -> Int? {
  if at < codes.length() && codes[at] == '#'.to_int() {
    css_name(codes, at + 1)
  } else {
    None
  }
}

///|
fn css_class(codes : Array[Int], at : Int) -> Int? {
  if at < codes.length() && codes[at] == '.'.to_int() {
    match css_ident(codes, at + 1) {
      Some(next) => Some(next)
      None => None
    }
  } else {
    None
  }
}

///|
fn css_attrib(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() || codes[at] != '['.to_int() {
    return None
  }
  let mut cursor = css_skip_ws(codes, at + 1)
  cursor = match css_namespace(codes, cursor) {
    Some(next) =>
      match css_ident(codes, next) {
        Some(named) => named
        None => return None
      }
    None =>
      match css_ident(codes, cursor) {
        Some(named) => named
        None => return None
      }
  }
  cursor = css_skip_ws(codes, cursor)
  match css_matcher(codes, cursor) {
    Some(next) => {
      cursor = css_skip_ws(codes, next)
      cursor = match css_ident(codes, cursor) {
        Some(value) => value
        None =>
          match css_string(codes, cursor) {
            Some(value) => value
            None => return None
          }
      }
      cursor = css_skip_ws(codes, cursor)
    }
    None => ()
  }
  if cursor < codes.length() && codes[cursor] == ']'.to_int() {
    Some(cursor + 1)
  } else {
    None
  }
}

///|
fn css_matcher(codes : Array[Int], at : Int) -> Int? {
  if css_starts(codes, at, "$=") ||
    css_starts(codes, at, "*=") ||
    css_starts(codes, at, "~=") ||
    css_starts(codes, at, "|=") {
    Some(at + 2)
  } else if at < codes.length() && codes[at] == '='.to_int() {
    Some(at + 1)
  } else {
    None
  }
}

///|
fn css_ident(codes : Array[Int], at : Int) -> Int? {
  let mut cursor = at
  if cursor < codes.length() && codes[cursor] == '-'.to_int() {
    cursor = cursor + 1
  }
  match css_nmstart(codes, cursor) {
    Some(next) => Some(css_nmchars(codes, next))
    None => None
  }
}

///|
fn css_name(codes : Array[Int], at : Int) -> Int? {
  match css_nmchar(codes, at) {
    Some(next) => Some(css_nmchars(codes, next))
    None => None
  }
}

///|
fn css_nmchars(codes : Array[Int], at : Int) -> Int {
  let mut cursor = at
  let mut moving = true
  while moving {
    match css_nmchar(codes, cursor) {
      Some(next) => cursor = next
      None => moving = false
    }
  }
  cursor
}

///|
fn css_nmstart(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() {
    None
  } else {
    let code = codes[at]
    if css_letter(code) || code == '_'.to_int() || code > 127 {
      Some(at + 1)
    } else if code == '\\'.to_int() {
      css_escape(codes, at)
    } else {
      None
    }
  }
}

///|
fn css_nmchar(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() {
    None
  } else {
    let code = codes[at]
    if css_letter(code) ||
      css_digit(code) ||
      code == '_'.to_int() ||
      code == '-'.to_int() ||
      code > 127 {
      Some(at + 1)
    } else if code == '\\'.to_int() {
      css_escape(codes, at)
    } else {
      None
    }
  }
}

///|
fn css_escape(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() ||
    codes[at] != '\\'.to_int() ||
    at + 1 >= codes.length() {
    None
  } else if css_hex(codes[at + 1]) {
    let mut cursor = at + 1
    let mut count = 0
    while cursor < codes.length() && count < 6 && css_hex(codes[cursor]) {
      cursor = cursor + 1
      count = count + 1
    }
    Some(cursor)
  } else if !css_ws(codes[at + 1]) {
    Some(at + 2)
  } else {
    None
  }
}

///|
fn css_newline(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() {
    None
  } else if codes[at] == '\n'.to_int() || codes[at] == 12 {
    Some(at + 1)
  } else if codes[at] == '\r'.to_int() {
    if at + 1 < codes.length() && codes[at + 1] == '\n'.to_int() {
      Some(at + 2)
    } else {
      Some(at + 1)
    }
  } else {
    None
  }
}

///|
fn css_number(codes : Array[Int], at : Int) -> (Int, Int)? {
  let number_end = match css_dotted(codes, at) {
    Some(next) => next
    None =>
      match css_digits(codes, at) {
        Some(next) => next
        None => return None
      }
  }
  if number_end < codes.length() && codes[number_end] == '%'.to_int() {
    Some((number_end, number_end + 1))
  } else {
    match css_name(codes, number_end) {
      Some(unit_end) => Some((number_end, unit_end))
      None => Some((number_end, number_end))
    }
  }
}

///|
fn css_dotted(codes : Array[Int], at : Int) -> Int? {
  let mut cursor = at
  if cursor < codes.length() &&
    (codes[cursor] == '+'.to_int() || codes[cursor] == '-'.to_int()) {
    cursor = cursor + 1
  }
  while cursor < codes.length() && css_digit(codes[cursor]) {
    cursor = cursor + 1
  }
  if cursor >= codes.length() || codes[cursor] != '.'.to_int() {
    return None
  }
  cursor = cursor + 1
  let fraction = cursor
  while cursor < codes.length() && css_digit(codes[cursor]) {
    cursor = cursor + 1
  }
  if cursor == fraction {
    None
  } else {
    Some(cursor)
  }
}

///|
fn css_digits(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() || !css_digit(codes[at]) {
    None
  } else {
    let mut cursor = at + 1
    while cursor < codes.length() && css_digit(codes[cursor]) {
      cursor = cursor + 1
    }
    Some(cursor)
  }
}

///|
fn css_comment(codes : Array[Int], at : Int) -> Int? {
  if css_starts(codes, at, "<!--") {
    match css_thru(codes, at + 4, "-->") {
      Some(next) => Some(css_skip_ws(codes, next))
      None => None
    }
  } else if css_starts(codes, at, "/*") {
    match css_thru(codes, at + 2, "*/") {
      Some(next) => Some(css_skip_ws(codes, next))
      None => None
    }
  } else {
    None
  }
}

///|
fn css_thru(codes : Array[Int], at : Int, mark : String) -> Int? {
  let mut cursor = at
  let mut found = false
  while cursor < codes.length() && !found {
    if css_starts(codes, cursor, mark) {
      found = true
    } else {
      cursor = cursor + 1
    }
  }
  if found {
    Some(cursor + mark.length())
  } else {
    None
  }
}

///|
fn css_starts(codes : Array[Int], at : Int, mark : String) -> Bool {
  let mut cursor = at
  let mut matched = true
  for char in mark {
    if cursor >= codes.length() || codes[cursor] != char.to_int() {
      matched = false
    }
    cursor = cursor + 1
  }
  matched && mark.length() > 0
}

///|
fn css_skip_ws(codes : Array[Int], at : Int) -> Int {
  let mut cursor = at
  while cursor < codes.length() && css_ws(codes[cursor]) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn css_ws(code : Int) -> Bool {
  code == ' '.to_int() ||
  code == '\t'.to_int() ||
  code == '\n'.to_int() ||
  code == '\r'.to_int() ||
  code == 12
}

///|
fn css_letter(code : Int) -> Bool {
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'z'.to_int())
}

///|
fn css_digit(code : Int) -> Bool {
  code >= '0'.to_int() && code <= '9'.to_int()
}

///|
fn css_hex(code : Int) -> Bool {
  css_digit(code) ||
  (code >= 'A'.to_int() && code <= 'F'.to_int()) ||
  (code >= 'a'.to_int() && code <= 'f'.to_int())
}

///|
fn css_minify(items : Array[@value.Cell]) -> String raise EvalError {
  let now : Array[String] = []
  let later : Array[String] = []
  let mut expr = false
  let mut index = 0
  while index < items.length() {
    let step = css_minify_at(items, index, expr)
    index = step.next
    expr = step.expr
    match step.kept {
      Some((text, delayed)) =>
        if delayed {
          later.push(text)
        } else {
          now.push(text)
        }
      None => ()
    }
  }
  let buf = StringBuilder()
  for text in now {
    buf.write_string(text)
  }
  for text in later {
    buf.write_string(text)
  }
  buf.to_string()
}

///|
priv struct CssStep {
  next : Int
  expr : Bool
  kept : (String, Bool)?
}

///|
fn css_minify_at(
  items : Array[@value.Cell],
  index : Int,
  expr : Bool,
) -> CssStep raise EvalError {
  let item = items[index]
  if css_char(item, ';') {
    css_minify_semi(items, index, expr)
  } else if css_char(item, '{') {
    CssStep::{
      next: css_skip_semi_space(items, index + 1),
      expr,
      kept: Some(("{", true)),
    }
  } else if css_char(item, '}') && css_ahead(items, index + 1, ' ') {
    CssStep::{ next: index + 2, expr, kept: Some(("}", true)), }
  } else if css_char(item, ':') && css_ahead(items, index + 1, ' ') {
    CssStep::{ next: index + 2, expr, kept: Some((":", true)), }
  } else if css_char(item, '(') {
    if css_ahead(items, index + 1, ' ') {
      CssStep::{ next: index + 2, expr: true, kept: Some(("(", true)), }
    } else {
      CssStep::{
        next: index + 1,
        expr: true,
        kept: Some((css_form(item), false)),
      }
    }
  } else if css_char(item, ')') {
    if css_ahead(items, index + 1, ' ') {
      CssStep::{ next: index + 2, expr: false, kept: Some((")", true)), }
    } else {
      CssStep::{
        next: index + 1,
        expr: false,
        kept: Some((css_form(item), false)),
      }
    }
  } else if css_char(item, ',') && css_ahead(items, index + 1, ' ') {
    CssStep::{ next: index + 2, expr, kept: Some((",", true)), }
  } else if css_char(item, ' ') {
    css_minify_space(items, index, expr)
  } else if css_zero(item) {
    css_minify_zero(items, index, expr)
  } else if css_char(item, '+') &&
    index + 1 < items.length() &&
    css_number_cell_q(items[index + 1]) {
    CssStep::{ next: index + 1, expr, kept: None, }
  } else if css_char(item, '-') &&
    index + 1 < items.length() &&
    css_zero(items[index + 1]) {
    CssStep::{ next: index + 1, expr, kept: None, }
  } else if css_word(item, "and") &&
    css_ahead(items, index + 1, ' ') &&
    css_ahead_char(items, index + 2, '(') {
    CssStep::{ next: index + 2, expr, kept: Some(("and ", true)), }
  } else if css_word(item, "black") {
    CssStep::{ next: index + 1, expr, kept: Some(("#000", true)), }
  } else if css_word(item, "white") {
    CssStep::{ next: index + 1, expr, kept: Some(("#fff", true)), }
  } else {
    CssStep::{ next: index + 1, expr, kept: Some((css_form(item), false)), }
  }
}

///|
fn css_minify_semi(
  items : Array[@value.Cell],
  index : Int,
  expr : Bool,
) -> CssStep {
  let spaced = if css_ahead(items, index + 1, ' ') {
    index + 2
  } else {
    index + 1
  }
  if css_ahead_char(items, spaced, '}') {
    CssStep::{ next: spaced, expr, kept: None, }
  } else {
    let gap = css_skip_semi_space(items, index + 1)
    if css_ahead_char(items, gap, '}') {
      CssStep::{ next: gap, expr, kept: None, }
    } else {
      CssStep::{ next: gap, expr, kept: Some((";", true)), }
    }
  }
}

///|
fn css_minify_space(
  items : Array[@value.Cell],
  index : Int,
  expr : Bool,
) -> CssStep {
  if css_ahead_special(items, index + 1) {
    CssStep::{ next: index + 1, expr, kept: None, }
  } else if css_ahead(items, index + 1, '>') || css_ahead(items, index + 1, '~') {
    let next = if css_ahead(items, index + 2, ' ') {
      index + 3
    } else {
      index + 2
    }
    CssStep::{ next, expr, kept: Some((css_form(items[index + 1]), false)), }
  } else if !expr && css_ahead(items, index + 1, '+') {
    let next = if css_ahead(items, index + 2, ' ') {
      index + 3
    } else {
      index + 2
    }
    CssStep::{ next, expr, kept: Some(("+", false)), }
  } else if expr &&
    css_ahead(items, index + 1, '/') &&
    css_ahead(items, index + 2, ' ') {
    CssStep::{ next: index + 3, expr, kept: Some(("/", true)), }
  } else if expr &&
    css_ahead(items, index + 1, '*') &&
    css_ahead(items, index + 2, ' ') {
    CssStep::{ next: index + 3, expr, kept: Some(("*", true)), }
  } else if index + 1 == items.length() {
    CssStep::{ next: index + 1, expr, kept: None, }
  } else {
    CssStep::{ next: index + 1, expr, kept: Some((" ", false)), }
  }
}

///|
fn css_minify_zero(
  items : Array[@value.Cell],
  index : Int,
  expr : Bool,
) -> CssStep raise EvalError {
  if index + 1 < items.length() && css_word(items[index + 1], "ms") {
    CssStep::{ next: index + 2, expr, kept: Some(("0s", true)), }
  } else if index + 1 < items.length() &&
    (css_char(items[index + 1], '%') || css_is_string(items[index + 1])) &&
    !(index + 2 < items.length() && css_char(items[index + 2], ',')) {
    CssStep::{ next: index + 2, expr, kept: Some(("0", true)), }
  } else {
    CssStep::{
      next: index + 1,
      expr,
      kept: Some((css_form(items[index]), false)),
    }
  }
}

///|
fn css_skip_semi_space(items : Array[@value.Cell], index : Int) -> Int {
  let mut cursor = index
  while cursor < items.length() &&
        (css_char(items[cursor], ' ') || css_char(items[cursor], ';')) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn css_ahead_special(items : Array[@value.Cell], index : Int) -> Bool {
  index < items.length() &&
  (
    css_char(items[index], '{') ||
    css_char(items[index], '}') ||
    css_char(items[index], '(') ||
    css_char(items[index], ')') ||
    css_char(items[index], ':') ||
    css_char(items[index], ';') ||
    css_char(items[index], ',')
  )
}

///|
fn css_ahead(items : Array[@value.Cell], index : Int, char : Char) -> Bool {
  index < items.length() && css_char(items[index], char)
}

///|
fn css_ahead_char(items : Array[@value.Cell], index : Int, char : Char) -> Bool {
  css_ahead(items, index, char)
}

///|
fn css_char(item : @value.Cell, char : Char) -> Bool {
  match item {
    @value.Char(code) => code == char.to_int()
    _ => false
  }
}

///|
fn css_word(item : @value.Cell, expected : String) -> Bool raise EvalError {
  match item {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index).to_lower() == expected
    _ => false
  }
}

///|
fn css_is_string(item : @value.Cell) -> Bool {
  match item {
    @value.Seq(series, _) => series.datatype() == @value.String
    _ => false
  }
}

///|
fn css_number_cell_q(item : @value.Cell) -> Bool {
  match item {
    @value.Integer(_) | @value.Decimal(_) => true
    _ => false
  }
}

///|
fn css_zero(item : @value.Cell) -> Bool {
  match item {
    @value.Integer(0L) => true
    @value.Decimal(number) => number == 0.0
    _ => false
  }
}

///|
fn css_form(item : @value.Cell) -> String {
  @mold.form_text(item)
}
