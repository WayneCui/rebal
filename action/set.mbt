///|
pub fn union(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match (read_items(left), read_items(right)) {
    (Some(left_items), Some(right_items)) => {
      let kept = unique_items(left_items)
      for item in right_items {
        if !has_item(kept, item) {
          kept.push(item)
        }
      }
      Ok(block_cell(kept))
    }
    _ =>
      match (read_codes(left), read_codes(right)) {
        (Some(left_codes), Some(right_codes)) => {
          let kept = unique_codes(left_codes)
          for code in right_codes {
            if !has_code(kept, code) {
              kept.push(code)
            }
          }
          Ok(text_cell(kept))
        }
        _ => Err(Cannot("union"))
      }
  }
}

///|
pub fn intersect(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match (read_items(left), read_items(right)) {
    (Some(left_items), Some(right_items)) => {
      let kept : Array[@value.Cell] = []
      for item in left_items {
        if has_item(right_items, item) && !has_item(kept, item) {
          kept.push(item)
        }
      }
      Ok(block_cell(kept))
    }
    _ =>
      match (read_codes(left), read_codes(right)) {
        (Some(left_codes), Some(right_codes)) => {
          let kept : Array[Int] = []
          for code in left_codes {
            if has_code(right_codes, code) && !has_code(kept, code) {
              kept.push(code)
            }
          }
          Ok(text_cell(kept))
        }
        _ => Err(Cannot("intersect"))
      }
  }
}

///|
pub fn difference(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match (read_items(left), read_items(right)) {
    (Some(left_items), Some(right_items)) => {
      let kept = exclude_items(left_items, right_items)
      for item in right_items {
        if !has_item(left_items, item) && !has_item(kept, item) {
          kept.push(item)
        }
      }
      Ok(block_cell(kept))
    }
    _ =>
      match (read_codes(left), read_codes(right)) {
        (Some(left_codes), Some(right_codes)) => {
          let kept = exclude_codes(left_codes, right_codes)
          for code in right_codes {
            if !has_code(left_codes, code) && !has_code(kept, code) {
              kept.push(code)
            }
          }
          Ok(text_cell(kept))
        }
        _ => Err(Cannot("difference"))
      }
  }
}

///|
pub fn exclude(
  left : @value.Cell,
  right : @value.Cell,
) -> Result[@value.Cell, ActionError] {
  match (read_items(left), read_items(right)) {
    (Some(left_items), Some(right_items)) =>
      Ok(block_cell(exclude_items(left_items, right_items)))
    _ =>
      match (read_codes(left), read_codes(right)) {
        (Some(left_codes), Some(right_codes)) =>
          Ok(text_cell(exclude_codes(left_codes, right_codes)))
        _ => Err(Cannot("exclude"))
      }
  }
}

///|
pub fn unique(cell : @value.Cell) -> Result[@value.Cell, ActionError] {
  match read_items(cell) {
    Some(items) => Ok(block_cell(unique_items(items)))
    None =>
      match read_codes(cell) {
        Some(codes) => Ok(text_cell(unique_codes(codes)))
        None => Err(Cannot("unique"))
      }
  }
}

///|
fn exclude_items(
  left : Array[@value.Cell],
  right : Array[@value.Cell],
) -> Array[@value.Cell] {
  let kept : Array[@value.Cell] = []
  for item in left {
    if !has_item(right, item) && !has_item(kept, item) {
      kept.push(item)
    }
  }
  kept
}

///|
fn exclude_codes(left : Array[Int], right : Array[Int]) -> Array[Int] {
  let kept : Array[Int] = []
  for code in left {
    if !has_code(right, code) && !has_code(kept, code) {
      kept.push(code)
    }
  }
  kept
}

///|
fn unique_items(items : Array[@value.Cell]) -> Array[@value.Cell] {
  let kept : Array[@value.Cell] = []
  for item in items {
    if !has_item(kept, item) {
      kept.push(item)
    }
  }
  kept
}

///|
fn unique_codes(codes : Array[Int]) -> Array[Int] {
  let kept : Array[Int] = []
  for code in codes {
    if !has_code(kept, code) {
      kept.push(code)
    }
  }
  kept
}

///|
fn has_item(items : Array[@value.Cell], value : @value.Cell) -> Bool {
  let mut found = false
  for item in items {
    if !found && equal(item, value) {
      found = true
    }
  }
  found
}

///|
fn has_code(codes : Array[Int], value : Int) -> Bool {
  let mut found = false
  for code in codes {
    if !found && code == value {
      found = true
    }
  }
  found
}

///|
fn read_items(cell : @value.Cell) -> Array[@value.Cell]? {
  match cell {
    @value.Seq(series, index) =>
      match series.datatype() {
        @value.Block | @value.Paren | @value.Path | @value.SetPath => {
          let items : Array[@value.Cell] = []
          for i in index..<series.length() {
            match series.item(i) {
              Some(item) => items.push(item)
              None => ()
            }
          }
          Some(items)
        }
        _ => None
      }
    _ => None
  }
}

///|
fn read_codes(cell : @value.Cell) -> Array[Int]? {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.String => {
      let codes : Array[Int] = []
      for i in index..<series.length() {
        match series.code(i) {
          Some(code) => codes.push(code)
          None => ()
        }
      }
      Some(codes)
    }
    _ => None
  }
}

///|
fn block_cell(items : Array[@value.Cell]) -> @value.Cell {
  let series = @value.Series::block()
  for item in items {
    series.push_item(item) |> ignore
  }
  @value.Seq(series, 0)
}

///|
fn text_cell(codes : Array[Int]) -> @value.Cell {
  let series = @value.Series::text()
  for code in codes {
    series.push_code(code) |> ignore
  }
  @value.Seq(series, 0)
}
