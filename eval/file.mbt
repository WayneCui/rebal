///|
#borrow(path)
extern "C" fn c_read_text(path : String, path_len : Int) -> String = "rebal_read_text"

///|
extern "C" fn c_io_status() -> Int = "rebal_io_status"

///|
#borrow(path, text)
extern "C" fn c_write_text(
  path : String,
  path_len : Int,
  text : String,
  text_len : Int,
) -> Int = "rebal_write_text"

///|
fn read_file(path : String) -> String raise EvalError {
  let text = c_read_text(path, path.length())
  if c_io_status() == 0 {
    text
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
pub fn write_file(path : String, text : String) -> Unit raise EvalError {
  if c_write_text(path, path.length(), text, text.length()) == 0 {
    ()
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
/// Reads a script, drops a leading `Rebol [header]` pair, and evaluates the rest.
fn do_text(env : Env, text : String) -> @value.Cell raise EvalError {
  eval(env, drop_header(load(env, text)))
}

///|
fn perform_load(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let (header, all, kind) = load_flags(env, args, active)
  let source = args[0]
  match kind {
    Some(name) =>
      if name == "markup" {
        return decode_markup(source)
      } else {
        raise EvalError::Cannot("access")
      }
    None => ()
  }
  if pkix_file(source) {
    match read_pem(read_file(loaded_path(source))) {
      Some(pem) => pem_block(env, pem)
      None => @value.None
    }
  } else if key_file(source) {
    decode_ssh_key(env, text_series(read_file(loaded_path(source))))
  } else if ppk_file(source) {
    decode_ppk(env, text_series(read_file(loaded_path(source))), None)
  } else {
    match source {
      @value.Seq(series, index) if series.datatype() == @value.Binary =>
        load_bytes(env, drop_bom(bytes_from(series, index)), header, all)
      _ => load_bytes(env, utf8_bytes(source_text(source)), header, all)
    }
  }
}

///|
/// `/header` wins over `/all`. `/all` returns every value and leaves a header unread.
/// `/as` names a codec. `markup` is handled here; any other name is refused.
fn load_flags(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> (Bool, Bool, String?) raise EvalError {
  let mut header = false
  let mut all = false
  let mut kind : String? = None
  let mut cursor = 1
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "header" {
      header = true
    } else if name == "all" {
      all = true
    } else if name == "as" {
      kind = Some(load_type(env, args[cursor]))
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("load")
    }
  }
  if header {
    (true, false, kind)
  } else {
    (false, all, kind)
  }
}

///|
fn load_type(env : Env, cell : @value.Cell) -> String raise EvalError {
  match cell {
    @value.Sym(_, lexeme) => env.symbols.canon(lexeme.sym())
    _ => raise EvalError::Cannot("load")
  }
}

///|
/// %.pem, %.ssh, and %.certSigningRequest are PKIX armor, as in codec-pkix.reb.
fn pkix_file(source : @value.Cell) -> Bool raise EvalError {
  match source {
    @value.Seq(series, _) if series.datatype() == @value.File =>
      match perform_suffix(source) {
        @value.Seq(suffix, index) => {
          let name = text_from(suffix, index).to_lower()
          name == ".pem" || name == ".ssh" || name == ".certsigningrequest"
        }
        _ => false
      }
    _ => false
  }
}

///|
/// %.ppk is a PuTTY key, as in codec-ppk.reb.
fn ppk_file(source : @value.Cell) -> Bool raise EvalError {
  suffix_is(source, ".ppk")
}

///|
/// %.key is an SSH key, as in codec-ssh-key.reb.
fn key_file(source : @value.Cell) -> Bool raise EvalError {
  suffix_is(source, ".key")
}

///|
fn suffix_is(source : @value.Cell, suffix : String) -> Bool raise EvalError {
  match source {
    @value.Seq(series, _) if series.datatype() == @value.File =>
      match perform_suffix(source) {
        @value.Seq(named, index) => text_from(named, index).to_lower() == suffix
        _ => false
      }
    _ => false
  }
}

///|
fn loaded_path(source : @value.Cell) -> String raise EvalError {
  match source {
    @value.Seq(series, index) if series.datatype() == @value.File =>
      text_from(series, index)
    _ => raise EvalError::Cannot("load")
  }
}

///|
fn perform_save(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let place = args[0]
  let script = save_script(args[1])
  let bytes = binary_cell(save_bytes(env, script, active, args))
  match place {
    @value.Cell::None => bytes
    @value.Seq(series, index) if series.datatype() == @value.File => {
      write_file(text_from(series, index), script)
      place
    }
    @value.Seq(series, _) if series.datatype() == @value.Binary =>
      match @series.append(place, bytes) {
        Some(saved) => saved
        None => raise EvalError::Cannot("save")
      }
    @value.Seq(series, _) if series.datatype() == @value.String =>
      match @series.append(place, @mold.cell(@mold.mold_text(bytes))) {
        Some(saved) => saved
        None => raise EvalError::Cannot("save")
      }
    _ => raise EvalError::Cannot("save")
  }
}

///|
/// `/compress false` is the zlib payload. `true` prefixes the boot header.
/// `'script` molds that payload as base 64. A custom header is not accepted.
fn save_bytes(
  env : Env,
  script : String,
  active : Array[Int],
  args : Array[@value.Cell],
) -> Array[Int] raise EvalError {
  match save_mode(env, active, args) {
    None => utf8_bytes(script)
    Some(mode) => save_compressed(env, script, mode)
  }
}

///|
fn save_mode(
  env : Env,
  active : Array[Int],
  args : Array[@value.Cell],
) -> @value.Cell? raise EvalError {
  let mut mode : @value.Cell? = None
  let mut cursor = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "compress" {
      mode = Some(args[cursor])
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("save")
    }
  }
  mode
}

///|
fn save_compressed(
  env : Env,
  script : String,
  mode : @value.Cell,
) -> Array[Int] raise EvalError {
  let packed = save_zlib(script)
  match mode {
    @value.Logic(false) => packed
    @value.Logic(true) => save_cat(save_header(), packed)
    @value.Sym(_, lexeme) =>
      if env.symbols.canon(lexeme.sym()) == "script" {
        utf8_bytes(save_header() + "64#{" + encode_base64(packed, false) + "}")
      } else {
        save_cat(save_header(), packed)
      }
    _ => raise EvalError::Cannot("save")
  }
}

///|
fn save_zlib(script : String) -> Array[Int] raise EvalError {
  let bytes = utf8_bytes(script)
  let packed = c_zlib_compress(latin_text(bytes), bytes.length(), -1, 15)
  if c_zlib_code() != 0 {
    raise EvalError::Cannot("save")
  }
  codes_of(packed)
}

///|
fn save_header() -> String {
  "REBOL [\n    options: [compress]\n]\n"
}

///|
fn save_cat(prefix : String, bytes : Array[Int]) -> Array[Int] {
  let out = utf8_bytes(prefix)
  for byte in bytes {
    out.push(byte)
  }
  out
}

///|
/// `mold/only` plus a newline. A block is written without its outer brackets.
fn save_script(value : @value.Cell) -> String {
  let molded = match value {
    @value.Seq(series, _) if series.datatype() == @value.Block =>
      text_contents(@mold.mold_text(value))
    _ => @mold.mold_text(value)
  }
  molded + "\n"
}

///|
fn source_text(source : @value.Cell) -> String raise EvalError {
  match source {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.File =>
      read_file(text_from(series, index))
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      qp_text(bytes_from(series, index)) catch {
        _ => raise EvalError::Cannot("load")
      }
    _ => raise EvalError::Cannot("load")
  }
}

///|
/// Boot `load` returns the only remaining value. A longer body stays a block.
fn singular(cell : @value.Cell) -> @value.Cell {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      if series.length() - index == 1 {
        match series.item(index) {
          Some(item) => item
          None => cell
        }
      } else {
        cell
      }
    _ => cell
  }
}

///|
/// A script header is the word `rebol` followed by a block. The word's case
/// does not matter. Anything else is left in place.
fn drop_header(cell : @value.Cell) -> @value.Cell {
  match cell {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      if index + 1 < series.length() &&
        rebol_word(series.item(index)) &&
        header_block(series.item(index + 1)) {
        @value.Seq(series, index + 2)
      } else {
        cell
      }
    _ => cell
  }
}

///|
fn rebol_word(cell : @value.Cell?) -> Bool {
  match cell {
    Some(@value.Sym(@value.Word, lexeme)) =>
      lexeme.spelling().to_lower() == "rebol"
    _ => false
  }
}

///|
fn header_block(cell : @value.Cell?) -> Bool {
  match cell {
    Some(@value.Seq(series, _)) => series.datatype() == @value.Block
    _ => false
  }
}
