///|
/// Bulletin-board markup, as in codec-bbcode.reb. Text starts in a paragraph.
/// A tag such as `quote` or `list` records the HTML element it opened, so the
/// matching close is ignored and the element stays open until the end.
fn decode_bbcode(value : @value.Cell) -> @value.Cell raise EvalError {
  let text = match value {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      string_utf8(value, bytes_from(series, index))
    @value.Seq(series, index) if series.datatype() == @value.File =>
      string_utf8(
        binary_cell(read_binary(text_from(series, index))),
        read_binary(text_from(series, index)),
      )
    _ => raise EvalError::Caused("expect-arg", "decode")
  }
  text_series(bb_convert(text))
}

///|
fn bb_text(parts : Array[String]) -> String {
  let buf = StringBuilder()
  for part in parts {
    buf.write_string(part)
  }
  buf.to_string()
}

///|
fn bb_convert(text : String) -> String {
  let codes = css_codes(text)
  let html : Array[String] = []
  let opened : Array[String] = []
  bb_open_p(html, opened)
  let mut at = 0
  while at < codes.length() {
    let next = bb_step(codes, at, html, opened)
    if next <= at {
      break
    }
    at = next
  }
  if opened.length() > 0 {
    bb_close(html, opened, None)
  }
  bb_text(html)
}

///|
fn bb_step(
  codes : Array[Int],
  at : Int,
  html : Array[String],
  opened : Array[String],
) -> Int {
  match bb_plain(codes, at, html) {
    Some(next) => return next
    None => ()
  }
  match bb_url_shortcut(codes, at, html) {
    Some(next) => return next
    None => ()
  }
  match bb_email_shortcut(codes, at, html) {
    Some(next) => return next
    None => ()
  }
  match bb_img(codes, at, html) {
    Some(next) => return next
    None => ()
  }
  match bb_fenced(codes, at, html, "[code]", "[/code]") {
    Some(next) => return next
    None => ()
  }
  match bb_fenced(codes, at, html, "[rebol]", "[/rebol]") {
    Some(next) => return next
    None => ()
  }
  match bb_close_all(codes, at, html, opened) {
    Some(next) => return next
    None => ()
  }
  match bb_br(codes, at, html) {
    Some(next) => return next
    None => ()
  }
  match bb_hr(codes, at, html) {
    Some(next) => return next
    None => ()
  }
  match bb_ignore(codes, at) {
    Some(next) => return next
    None => ()
  }
  match bb_tag(codes, at, html, opened) {
    Some(next) => return next
    None => ()
  }
  match bb_lt(codes, at, html) {
    Some(next) => return next
    None => ()
  }
  match bb_break(codes, at, html, opened) {
    Some(next) => next
    None => at
  }
}

///|
fn bb_plain(codes : Array[Int], at : Int, html : Array[String]) -> Int? {
  if at >= codes.length() || !bb_normal(codes[at]) {
    return None
  }
  let mut cursor = at + 1
  while cursor < codes.length() && bb_normal(codes[cursor]) {
    cursor = cursor + 1
  }
  html.push(css_span(codes, at, cursor))
  Some(cursor)
}

///|
fn bb_normal(code : Int) -> Bool {
  code != '['.to_int() &&
  code != '<'.to_int() &&
  code != '\r'.to_int() &&
  code != '\n'.to_int()
}

///|
fn bb_url_shortcut(codes : Array[Int], at : Int, html : Array[String]) -> Int? {
  bb_linked(codes, at, html, "[url]", "[/url]", "")
}

///|
fn bb_email_shortcut(
  codes : Array[Int],
  at : Int,
  html : Array[String],
) -> Int? {
  bb_linked(codes, at, html, "[email]", "[/email]", "mailto:")
}

///|
fn bb_linked(
  codes : Array[Int],
  at : Int,
  html : Array[String],
  open : String,
  close : String,
  prefix : String,
) -> Int? {
  if !css_starts(codes, at, open) {
    return None
  }
  let start = at + open.length()
  match bb_url_run(codes, start) {
    Some(end) => {
      let mut cursor = end
      if css_starts(codes, cursor, close) {
        cursor = cursor + close.length()
      }
      let body = css_span(codes, start, end)
      let href = bb_escape(prefix + body)
      html.push("<a href=\"" + href + "\">" + body + "</a>")
      Some(cursor)
    }
    None => None
  }
}

///|
fn bb_url_run(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() || !bb_url_char(codes[at]) {
    None
  } else {
    let mut cursor = at + 1
    while cursor < codes.length() && bb_url_char(codes[cursor]) {
      cursor = cursor + 1
    }
    Some(cursor)
  }
}

///|
fn bb_url_char(code : Int) -> Bool {
  css_letter(code) ||
  css_digit(code) ||
  code == '.'.to_int() ||
  code == '/'.to_int() ||
  code == ':'.to_int() ||
  code == '~'.to_int() ||
  code == '+'.to_int() ||
  code == '-'.to_int() ||
  code == '%'.to_int() ||
  code == '#'.to_int() ||
  code == '\\'.to_int() ||
  code == '_'.to_int() ||
  code == '='.to_int() ||
  code == '&'.to_int() ||
  code == '?'.to_int() ||
  code == '@'.to_int()
}

///|
fn bb_img(codes : Array[Int], at : Int, html : Array[String]) -> Int? {
  if !css_starts(codes, at, "[img]") {
    return None
  }
  let start = at + 5
  match bb_url_run(codes, start) {
    Some(end) => {
      let mut cursor = end
      if css_starts(codes, cursor, "[/img]") {
        cursor = cursor + 6
      }
      html.push(
        "<img src=\"" + bb_escape(css_span(codes, start, end)) + "\" alt=\"\">",
      )
      Some(cursor)
    }
    None => None
  }
}

///|
fn bb_fenced(
  codes : Array[Int],
  at : Int,
  html : Array[String],
  open : String,
  close : String,
) -> Int? {
  if !css_starts(codes, at, open) {
    return None
  }
  let start = at + open.length()
  match css_thru(codes, start, close) {
    Some(next) => {
      let body_end = next - close.length()
      html.push("<code>" + css_span(codes, start, body_end) + "</code>")
      Some(next)
    }
    None => None
  }
}

///|
fn bb_close_all(
  codes : Array[Int],
  at : Int,
  html : Array[String],
  opened : Array[String],
) -> Int? {
  if css_starts(codes, at, "[/]") {
    bb_close(html, opened, None)
    Some(at + 3)
  } else {
    None
  }
}

///|
fn bb_br(codes : Array[Int], at : Int, html : Array[String]) -> Int? {
  if css_starts(codes, at, "[br]") {
    html.push("<br>")
    Some(at + 4)
  } else {
    None
  }
}

///|
fn bb_hr(codes : Array[Int], at : Int, html : Array[String]) -> Int? {
  if !css_starts(codes, at, "[hr") {
    return None
  }
  let mut cursor = css_skip_ws(codes, at + 3)
  let start = cursor
  while cursor < codes.length() && css_digit(codes[cursor]) {
    cursor = cursor + 1
  }
  if cursor < codes.length() && codes[cursor] == '%'.to_int() && cursor > start {
    cursor = cursor + 1
  }
  let width = css_span(codes, start, cursor)
  cursor = css_skip_ws(codes, cursor)
  if cursor >= codes.length() || codes[cursor] != ']'.to_int() {
    None
  } else if width == "" {
    html.push("<hr>")
    Some(cursor + 1)
  } else {
    html.push("<hr style=\"width:" + width + "\">")
    Some(cursor + 1)
  }
}

///|
fn bb_ignore(codes : Array[Int], at : Int) -> Int? {
  if css_starts(codes, at, "[ignore]") {
    match css_thru(codes, at + 8, "[/ignore]") {
      Some(next) => Some(next)
      None => None
    }
  } else {
    None
  }
}

///|
fn bb_lt(codes : Array[Int], at : Int, html : Array[String]) -> Int? {
  if at < codes.length() && codes[at] == '<'.to_int() {
    html.push("&lt;")
    Some(at + 1)
  } else {
    None
  }
}

///|
fn bb_break(
  codes : Array[Int],
  at : Int,
  html : Array[String],
  opened : Array[String],
) -> Int? {
  match bb_newline(codes, at) {
    Some(one) =>
      match bb_newline(codes, one) {
        Some(two) => {
          bb_close(html, opened, Some("p"))
          html.push("\n\n")
          bb_open_p(html, opened)
          Some(two)
        }
        None => {
          if at > 0 && codes[at - 1] == ' '.to_int() {
            html.push("<br>\n")
          } else {
            html.push("\n")
          }
          Some(one)
        }
      }
    None => None
  }
}

///|
fn bb_newline(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() {
    None
  } else if codes[at] == '\n'.to_int() {
    Some(at + 1)
  } else if codes[at] == '\r'.to_int() &&
    at + 1 < codes.length() &&
    codes[at + 1] == '\n'.to_int() {
    Some(at + 2)
  } else {
    None
  }
}

///|
priv struct BbTag {
  name : String
  short : String
  next : Int
}

///|
fn bb_tag(
  codes : Array[Int],
  at : Int,
  html : Array[String],
  opened : Array[String],
) -> Int? {
  if at >= codes.length() || codes[at] != '['.to_int() {
    return None
  }
  if at + 1 < codes.length() && codes[at + 1] == '/'.to_int() {
    return bb_shut(codes, at, html, opened)
  }
  match bb_read_tag(codes, at + 1) {
    Some(tag) =>
      if bb_enabled(tag.name) {
        bb_open(html, opened, tag.name, tag.short)
        Some(tag.next)
      } else {
        html.push("[" + tag.name + bb_shown(tag.short) + "]")
        Some(tag.next)
      }
    None => {
      html.push("[")
      Some(at + 1)
    }
  }
}

///|
fn bb_shown(short : String) -> String {
  if short == "" {
    ""
  } else {
    "=" + short
  }
}

///|
fn bb_read_tag(codes : Array[Int], at : Int) -> BbTag? {
  match bb_name(codes, at) {
    Some(named) => {
      let mut cursor = named
      let mut short = ""
      if cursor < codes.length() && codes[cursor] == '='.to_int() {
        let read = bb_value(codes, cursor + 1)
        short = read.0
        cursor = read.1
      }
      cursor = css_skip_ws(codes, cursor)
      if cursor < codes.length() && codes[cursor] == ']'.to_int() {
        Some(BbTag::{
          name: css_span(codes, at, named),
          short,
          next: cursor + 1,
        })
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn bb_value(codes : Array[Int], at : Int) -> (String, Int) {
  if at < codes.length() &&
    (codes[at] == '"'.to_int() || codes[at] == '\''.to_int()) {
    let quote = codes[at]
    let mut cursor = at + 1
    while cursor < codes.length() && codes[cursor] != quote {
      cursor = cursor + 1
    }
    let end = if cursor < codes.length() { cursor + 1 } else { cursor }
    (css_span(codes, at + 1, cursor), end)
  } else {
    let mut cursor = at
    while cursor < codes.length() && bb_value_char(codes[cursor]) {
      cursor = cursor + 1
    }
    (css_span(codes, at, cursor), cursor)
  }
}

///|
fn bb_value_char(code : Int) -> Bool {
  code != ' '.to_int() &&
  code != '\t'.to_int() &&
  code != '<'.to_int() &&
  code != '>'.to_int() &&
  code != ']'.to_int()
}

///|
fn bb_name(codes : Array[Int], at : Int) -> Int? {
  if at >= codes.length() || !bb_name_char(codes[at]) {
    None
  } else {
    let mut cursor = at + 1
    while cursor < codes.length() && bb_name_char(codes[cursor]) {
      cursor = cursor + 1
    }
    Some(cursor)
  }
}

///|
fn bb_name_char(code : Int) -> Bool {
  css_letter(code) || css_digit(code) || code == '*'.to_int()
}

///|
fn bb_shut(
  codes : Array[Int],
  at : Int,
  html : Array[String],
  opened : Array[String],
) -> Int? {
  match bb_name(codes, at + 2) {
    Some(named) =>
      if named < codes.length() && codes[named] == ']'.to_int() {
        let name = css_span(codes, at + 2, named)
        if bb_has(opened, name) {
          bb_close(html, opened, Some(name))
        }
        Some(named + 1)
      } else {
        None
      }
    None => None
  }
}

///|
fn bb_open(
  html : Array[String],
  opened : Array[String],
  name : String,
  short : String,
) -> Unit {
  let folded = name.to_lower()
  if folded == "*" {
    bb_open(html, opened, "li", short)
  } else if folded == "li" {
    bb_repeat_li(html, opened)
    bb_emit_open(html, opened, "li", short)
  } else if folded == "url" {
    opened.push("a")
    html.push("<a href=\"" + bb_escape(short) + "\">")
  } else if folded == "color" {
    if bb_hex_color(short) {
      opened.push("span")
      html.push("<span style=\"color: " + short + ";\">")
    }
  } else if folded == "quote" {
    opened.push("fieldset")
    opened.push("blockquote")
    if short == "" {
      html.push("<fieldset><blockquote>")
    } else {
      html.push("<fieldset><legend>" + short + "</legend><blockquote>")
    }
  } else if folded == "list" {
    bb_close_p(html, opened)
    match bb_list_open(short) {
      Some((tag, text)) => {
        opened.push(tag)
        html.push(text)
      }
      None => ()
    }
  } else if folded == "size" {
    opened.push("span")
    html.push(bb_size(short))
  } else if folded == "align" {
    opened.push("div")
    html.push(bb_align(short))
  } else if folded == "email" {
    opened.push("a")
    html.push("<a href=\"mailto:" + bb_escape(short) + "\">")
  } else if folded == "class" {
    opened.push("span")
    html.push("<span class=\"" + short + "\">")
  } else if bb_block_tag(folded) {
    bb_close_p(html, opened)
    bb_emit_open(html, opened, name, short)
  } else {
    bb_emit_open(html, opened, name, short)
  }
}

///|
fn bb_repeat_li(html : Array[String], opened : Array[String]) -> Unit {
  let mut found = -1
  let mut index = 0
  while index < opened.length() {
    if bb_same(opened[index], "li") {
      found = index
    }
    index = index + 1
  }
  if found >= 0 {
    let mut later = false
    let mut cursor = found
    while cursor < opened.length() {
      if bb_same(opened[cursor], "ol") || bb_same(opened[cursor], "ul") {
        later = true
      }
      cursor = cursor + 1
    }
    if !later {
      bb_close(html, opened, Some("li"))
    }
  }
}

///|
fn bb_emit_open(
  html : Array[String],
  opened : Array[String],
  name : String,
  short : String,
) -> Unit {
  opened.push(name)
  if short == "" {
    html.push("<" + name + ">")
  } else {
    html.push("<" + name + " class=\"" + bb_escape(short) + "\">")
  }
}

///|
fn bb_list_open(short : String) -> (String, String)? {
  if short == "a" {
    Some(("ol", "<ol style=\"list-style-type: lower-alpha;\">"))
  } else if short == "A" {
    Some(("ol", "<ol style=\"list-style-type: upper-alpha;\">"))
  } else if short == "i" {
    Some(("ol", "<ol style=\"list-style-type: lower-roman;\">"))
  } else if short == "I" {
    Some(("ol", "<ol style=\"list-style-type: upper-roman;\">"))
  } else if short == "1" {
    Some(("ol", "<ol style=\"list-style-type: decimal;\">"))
  } else {
    Some(("ul", "<ul>"))
  }
}

///|
fn bb_size(short : String) -> String {
  if short == "-2" || short == "tiny" || short == "xx-small" {
    "<span style=\"font-size: xx-small;\">"
  } else if short == "-1" || short == "x-small" {
    "<span style=\"font-size: x-small;\">"
  } else if short == "0" || short == "small" || short == "normal" {
    "<span style=\"font-size: small;\">"
  } else if short == "1" || short == "medium" {
    "<span style=\"font-size: medium;\">"
  } else if short == "2" || short == "large" {
    "<span style=\"font-size: large;\">"
  } else if short == "3" || short == "x-large" || short == "huge" {
    "<span style=\"font-size: x-large;\">"
  } else if short == "4" || short == "xx-large" {
    "<span style=\"font-size: xx-large;\">"
  } else {
    "<span>"
  }
}

///|
fn bb_align(short : String) -> String {
  if short == "right" || short == "r" {
    "<div style=\"text-align: right;\">"
  } else if short == "left" || short == "l" {
    "<div style=\"text-align: left;\">"
  } else if short == "center" || short == "c" {
    "<div style=\"text-align: center;\">"
  } else if short == "justify" || short == "j" {
    "<div style=\"text-align: justify;\">"
  } else {
    "<div>"
  }
}

///|
fn bb_hex_color(short : String) -> Bool {
  if short.length() != 4 && short.length() != 7 {
    return false
  }
  let mut hex = true
  let mut index = 0
  for char in short {
    if index == 0 {
      hex = char == '#'
    } else if !css_hex(char.to_int()) {
      hex = false
    }
    index = index + 1
  }
  hex
}

///|
fn bb_block_tag(name : String) -> Bool {
  name == "h1" ||
  name == "h2" ||
  name == "h3" ||
  name == "h4" ||
  name == "h5" ||
  name == "h6" ||
  name == "ul" ||
  name == "ol"
}

///|
fn bb_enabled(name : String) -> Bool {
  let folded = name.to_lower()
  folded == "b" ||
  folded == "i" ||
  folded == "s" ||
  folded == "u" ||
  folded == "del" ||
  folded == "h1" ||
  folded == "h2" ||
  folded == "h3" ||
  folded == "h4" ||
  folded == "h5" ||
  folded == "h6" ||
  folded == "span" ||
  folded == "class" ||
  folded == "ins" ||
  folded == "dd" ||
  folded == "dt" ||
  folded == "ol" ||
  folded == "ul" ||
  folded == "li" ||
  folded == "url" ||
  folded == "list" ||
  folded == "br" ||
  folded == "hr" ||
  folded == "color" ||
  folded == "quote" ||
  folded == "img" ||
  folded == "size" ||
  folded == "rebol" ||
  folded == "align" ||
  folded == "email" ||
  folded == "ignore" ||
  folded == "*"
}

///|
fn bb_close_p(html : Array[String], opened : Array[String]) -> Unit {
  if opened.length() > 0 && bb_same(opened[opened.length() - 1], "p") {
    bb_close(html, opened, Some("p"))
    let text = bb_text(html)
    if text.length() >= 7 && text[text.length() - 7:text.length()] == "<p></p>" {
      let kept = text[0:text.length() - 7].to_owned()
      while html.length() > 0 {
        html.pop() |> ignore
      }
      if kept != "" {
        html.push(kept)
      }
    }
  }
}

///|
fn bb_open_p(html : Array[String], opened : Array[String]) -> Unit {
  html.push("<p>")
  opened.push("p")
}

///|
fn bb_close(
  html : Array[String],
  opened : Array[String],
  only : String?,
) -> Unit {
  let mut closing = true
  while closing && opened.length() > 0 {
    let tag = opened[opened.length() - 1]
    opened.pop() |> ignore
    html.push(bb_ender(tag))
    match only {
      Some(name) => if bb_same(tag, name) { closing = false }
      None => ()
    }
  }
}

///|
fn bb_ender(tag : String) -> String {
  let folded = tag.to_lower()
  if folded == "url" {
    "</a>"
  } else if folded == "list" ||
    folded == "color" ||
    folded == "quote" ||
    folded == "size" ||
    folded == "align" ||
    folded == "email" {
    ""
  } else {
    "</" + tag + ">"
  }
}

///|
fn bb_has(opened : Array[String], name : String) -> Bool {
  let mut found = false
  for tag in opened {
    if bb_same(tag, name) {
      found = true
    }
  }
  found
}

///|
fn bb_same(left : String, right : String) -> Bool {
  left.to_lower() == right.to_lower()
}

///|
fn bb_escape(text : String) -> String {
  let buf = StringBuilder()
  for char in text {
    if char == '\'' {
      buf.write_string("&apos;")
    } else if char == '"' {
      buf.write_string("&quot;")
    } else {
      buf.write_char(char)
    }
  }
  buf.to_string()
}
