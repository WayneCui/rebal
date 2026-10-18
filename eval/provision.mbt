///|
/// Apple provisioning profile: CMS SignedData around an XML property list.
/// codec-plist.reb's provision decoder. A profile that is not that message is none.
fn decode_provision(
  env : Env,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  match provision_octets(env, decode_der(env, value)) {
    Some(bytes) => decode_plist(env, binary_cell(bytes))
    None => @value.Cell::None
  }
}

///|
fn provision_octets(env : Env, der : @value.Cell) -> Array[Int]? {
  match block_items(der) {
    Some(top) =>
      if top.length() == 2 && word_is(env, top[0], "sequence") {
        provision_signed(env, top[1])
      } else {
        None
      }
    None => None
  }
}

///|
fn provision_signed(env : Env, cell : @value.Cell) -> Array[Int]? {
  match block_items(cell) {
    Some(items) =>
      if items.length() >= 4 &&
        word_is(env, items[0], "object_identifier") &&
        provision_oid(items[1], provision_signed_oid()) &&
        word_is(env, items[2], "cs0") {
        provision_wrapped(env, items[3])
      } else {
        None
      }
    None => None
  }
}

///|
fn provision_wrapped(env : Env, cell : @value.Cell) -> Array[Int]? {
  match block_items(cell) {
    Some(items) =>
      if items.length() == 2 && word_is(env, items[0], "sequence") {
        provision_body(env, items[1])
      } else {
        None
      }
    None => None
  }
}

///|
fn provision_body(env : Env, cell : @value.Cell) -> Array[Int]? {
  match block_items(cell) {
    Some(items) =>
      if items.length() >= 6 &&
        word_is(env, items[0], "integer") &&
        word_is(env, items[2], "set") &&
        word_is(env, items[4], "sequence") {
        provision_encap(env, items[5])
      } else {
        None
      }
    None => None
  }
}

///|
fn provision_encap(env : Env, cell : @value.Cell) -> Array[Int]? {
  match block_items(cell) {
    Some(items) =>
      if items.length() >= 4 &&
        word_is(env, items[0], "object_identifier") &&
        provision_oid(items[1], provision_data_oid()) &&
        word_is(env, items[2], "cs0") {
        provision_octet(env, items[3])
      } else {
        None
      }
    None => None
  }
}

///|
fn provision_octet(env : Env, cell : @value.Cell) -> Array[Int]? {
  match block_items(cell) {
    Some(items) =>
      if items.length() >= 2 && word_is(env, items[0], "octet_string") {
        match items[1] {
          @value.Seq(series, index) if series.datatype() == @value.Binary =>
            Some(bytes_from(series, index))
          _ => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn provision_oid(cell : @value.Cell, expected : Array[Int]) -> Bool {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Binary => {
      let got = bytes_from(series, index)
      if got.length() != expected.length() {
        false
      } else {
        let mut cursor = 0
        let mut same = true
        while cursor < got.length() {
          if got[cursor] != expected[cursor] {
            same = false
          }
          cursor = cursor + 1
        }
        same
      }
    }
    _ => false
  }
}

///|
fn provision_signed_oid() -> Array[Int] {
  [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02]
}

///|
fn provision_data_oid() -> Array[Int] {
  [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x01]
}
