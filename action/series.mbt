///|
pub fn append(
  series : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  changed(series, "append", fn(cell) { @series.append(cell, value) })
}

///|
pub fn insert(
  series : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  changed(series, "insert", fn(cell) { @series.insert(cell, value) })
}

///|
pub fn remove(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "remove", fn(cell) { @series.remove(cell) })
}

///|
pub fn copy(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "copy", fn(cell) { @series.copy(cell) })
}

///|
pub fn find(
  series : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  seek(series, value, false, false, false, false, false, None)
}

///|
pub fn seek(
  series : @value.Cell,
  value : @value.Cell,
  last : Bool,
  reverse : Bool,
  match_only : Bool,
  tail : Bool,
  only : Bool,
  part : Int?,
) -> Result[@value.Cell, ActionError] {
  match series {
    @value.None => Ok(@value.None)
    @value.Bitset(bits) =>
      find_bitset(bits, value, last, reverse, match_only, tail, only, part)
    _ =>
      if is_series(series) {
        Ok(
          @series.find_with(
            series, value, last, reverse, match_only, tail, only, part,
          ),
        )
      } else {
        Err(Cannot("find"))
      }
  }
}

///|
fn find_bitset(
  bits : @value.Bitset,
  value : @value.Cell,
  last : Bool,
  reverse : Bool,
  match_only : Bool,
  tail : Bool,
  only : Bool,
  part : Int?,
) -> Result[@value.Cell, ActionError] {
  if last || reverse || match_only || tail || only || part is Some(_) {
    Err(Cannot("find"))
  } else {
    match bit_code(value) {
      Some(code) => if bits.has(code) { Ok(value) } else { Ok(@value.None) }
      None => Err(Cannot("find"))
    }
  }
}

///|
fn bit_code(value : @value.Cell) -> Int? {
  match value {
    @value.Char(code) => Some(code)
    @value.Integer(n) => if n >= 0L { Some(n.to_int()) } else { None }
    _ => None
  }
}

///|
pub fn select(
  series : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match series {
    @value.None => Ok(@value.None)
    @value.Map(map) =>
      match map.get(value) {
        Some(found) => Ok(found)
        None => Ok(@value.None)
      }
    _ =>
      if is_series(series) {
        Ok(@series.select(series, value))
      } else {
        Err(Cannot("select"))
      }
  }
}

///|
pub fn pick(
  series : @value.Cell,
  index : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match series {
    @value.Pair(x, y) =>
      match fit_int(index) {
        Some(1) => Ok(@value.Integer(x))
        Some(2) => Ok(@value.Integer(y))
        _ => Err(Cannot("pick"))
      }
    @value.Tuple(parts) =>
      match fit_int(index) {
        Some(n) if n >= 1 && n <= parts.length() =>
          Ok(@value.Integer(parts[n - 1].to_int64()))
        _ => Err(Cannot("pick"))
      }
    _ =>
      if is_series(series) {
        match fit_int(index) {
          Some(n) => Ok(@series.pick(series, n))
          None => Err(Cannot("pick"))
        }
      } else {
        Err(Cannot("pick"))
      }
  }
}

///|
pub fn length(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  match series {
    @value.Map(map) => Ok(@value.Integer(map.length().to_int64()))
    _ => length_series(series)
  }
}

///|
fn length_series(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  match @series.length(series) {
    Some(n) => Ok(@value.Integer(n.to_int64()))
    None => Err(Cannot("length?"))
  }
}

///|
/// `first` is `pick` of 1. An empty series is `none`.
pub fn first(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  match series {
    @value.Pair(x, _) => Ok(@value.Integer(x))
    @value.Tuple(parts) =>
      if parts.length() == 0 {
        Err(Cannot("first"))
      } else {
        Ok(@value.Integer(parts[0].to_int64()))
      }
    _ =>
      if is_series(series) {
        Ok(@series.pick(series, 1))
      } else {
        Err(Cannot("first"))
      }
  }
}

///|
fn changed(
  series : @value.Cell,
  name : String,
  op : (@value.Cell) -> @value.Cell?,
) -> Result[@value.Cell, ActionError] {
  if is_series(series) {
    match op(series) {
      Some(cell) => Ok(cell)
      None => Err(Cannot(name))
    }
  } else {
    Err(Cannot(name))
  }
}

///|
fn is_series(cell : @value.Cell) -> Bool {
  let datatype = cell.datatype()
  datatype == @value.Block ||
  datatype == @value.Paren ||
  datatype == @value.Path ||
  datatype == @value.SetPath ||
  datatype == @value.String ||
  datatype == @value.Binary
}

///|
fn fit_int(cell : @value.Cell) -> Int? {
  match cell {
    @value.Integer(n) =>
      if n >= -2147483648L && n <= 2147483647L {
        Some(n.to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn next(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "next", fn(cell) { @series.next(cell) })
}

///|
pub fn back(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "back", fn(cell) { @series.skip(cell, -1) })
}

///|
pub fn head(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "head", fn(cell) { @series.head(cell) })
}

///|
pub fn tail(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "tail", fn(cell) { @series.tail(cell) })
}

///|
pub fn skip(
  series : @value.Cell,
  offset : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match fit_int(offset) {
    Some(n) => changed(series, "skip", fn(cell) { @series.skip(cell, n) })
    None => Err(Cannot("skip"))
  }
}

///|
pub fn at(
  series : @value.Cell,
  index : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match fit_int(index) {
    Some(n) => changed(series, "at", fn(cell) { @series.at(cell, n) })
    None => Err(Cannot("at"))
  }
}

///|
pub fn index(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  match @series.index(series) {
    Some(n) => Ok(@value.Integer(n.to_int64()))
    None => Err(Cannot("index?"))
  }
}

///|
pub fn head_q(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  match @series.index(series) {
    Some(n) => Ok(@value.Logic(n == 1))
    None => Err(Cannot("head?"))
  }
}

///|
pub fn tail_q(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  match @series.is_tail(series) {
    Some(flag) => Ok(@value.Logic(flag))
    None => Err(Cannot("tail?"))
  }
}

///|
pub fn clear(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "clear", fn(cell) { @series.clear(cell) })
}

///|
pub fn take(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  match @series.take(series) {
    Some(value) => Ok(value)
    None => Err(Cannot("take"))
  }
}

///|
pub fn reverse(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "reverse", fn(cell) { @series.reverse(cell) })
}

///|
pub fn swap(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match @series.swap(left, right) {
    Some(cell) => Ok(cell)
    None => Err(Cannot("swap"))
  }
}

///|
pub fn change(
  series : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  changed(series, "change", fn(cell) { @series.change(cell, value) })
}

///|
pub fn trim(series : @value.Cell) -> Result[@value.Cell, ActionError] {
  changed(series, "trim", fn(cell) { @series.trim(cell) })
}

///|
pub fn poke(
  series : @value.Cell,
  index : @value.Cell,
  value : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match fit_int(index) {
    Some(n) =>
      changed(series, "poke", fn(cell) { @series.poke(cell, n, value) })
    None => Err(Cannot("poke"))
  }
}
