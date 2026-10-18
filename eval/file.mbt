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
#borrow(path)
extern "C" fn c_read_bytes(path : String, path_len : Int) -> String = "rebal_read_bytes"

///|
#borrow(path, data)
extern "C" fn c_write_bytes(
  path : String,
  path_len : Int,
  data : String,
  data_len : Int,
) -> Int = "rebal_write_bytes"

///|
fn read_binary(path : String) -> Array[Int] raise EvalError {
  let text = c_read_bytes(path, path.length())
  if c_io_status() == 0 {
    codes_of(text)
  } else {
    raise EvalError::Cannot("access")
  }
}

///|
pub fn write_binary(path : String, bytes : Array[Int]) -> Unit raise EvalError {
  if c_write_bytes(path, path.length(), latin_text(bytes), bytes.length()) == 0 {
    ()
  } else {
    raise EvalError::Cannot("access")
  }
}

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
/// `/as` selects a codec, or asks for the source to be loaded as code.
priv enum LoadAs {
  Plain
  Script
  Codec(String)
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
  let (header, all, mode) = load_flags(env, args, active)
  let source = args[0]
  match source {
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      return load_each(env, series, index, args, active)
    _ => ()
  }
  match mode {
    Codec(name) =>
      if name == "markup" {
        return decode_markup(source)
      } else if name == "text" {
        return load_text(source)
      } else {
        raise EvalError::Cannot("access")
      }
    Script => return load_script(env, source, header, all)
    Plain => ()
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
  } else if text_file(source) {
    load_text(source)
  } else if markup_file(source) {
    decode_markup(source)
  } else if json_file(source) {
    decode_json(env, text_series(source_text(source)))
  } else if gzip_file(source) {
    binary_cell(gzip_unpack(read_binary(loaded_path(source))))
  } else if tar_suffix(source) {
    decode_tar(
      binary_cell(read_binary(loaded_path(source))),
      false,
      @value.Cell::None,
    )
  } else if zip_suffix(source) {
    zip_block(read_binary(loaded_path(source)))
  } else {
    match source {
      @value.Seq(series, index) if series.datatype() == @value.Binary =>
        load_bytes(env, drop_bom(bytes_from(series, index)), header, all)
      _ => load_bytes(env, utf8_bytes(source_text(source)), header, all)
    }
  }
}

///|
/// Each value in a block is loaded on its own. The results stay a block.
fn load_each(
  env : Env,
  series : @value.Series,
  index : Int,
  args : Array[@value.Cell],
  active : Array[Int],
) -> @value.Cell raise EvalError {
  let block = @value.Series::block()
  for at in index..<series.length() {
    match series.item(at) {
      Some(item) => {
        let nested : Array[@value.Cell] = [item]
        for n in 1..<args.length() {
          nested.push(args[n])
        }
        block.push_item(perform_load(env, nested, active)) |> ignore
      }
      None => ()
    }
  }
  @value.Seq(block, 0)
}

///|
/// `/header` wins over `/all`. `/all` returns every value and leaves a header unread.
/// `/as text` decodes UTF-8. `/as none` and `/as unbound` load code and ignore a file suffix.
fn load_flags(
  env : Env,
  args : Array[@value.Cell],
  active : Array[Int],
) -> (Bool, Bool, LoadAs) raise EvalError {
  let mut header = false
  let mut all = false
  let mut mode = Plain
  let mut cursor = 1
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "header" {
      header = true
    } else if name == "all" {
      all = true
    } else if name == "as" {
      mode = load_type(env, args[cursor])
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("load")
    }
  }
  if header {
    (true, false, mode)
  } else {
    (false, all, mode)
  }
}

///|
fn load_type(env : Env, cell : @value.Cell) -> LoadAs raise EvalError {
  match cell {
    @value.Cell::None => Script
    @value.Sym(_, lexeme) => {
      let name = env.symbols.canon(lexeme.sym())
      if name == "unbound" {
        Script
      } else {
        Codec(name)
      }
    }
    _ => raise EvalError::Caused("expect-arg", "load")
  }
}

///|
/// `/as none` loads the bytes as a script, even when the suffix names a codec.
fn load_script(
  env : Env,
  source : @value.Cell,
  header : Bool,
  all : Bool,
) -> @value.Cell raise EvalError {
  match source {
    @value.Seq(series, index) if series.datatype() == @value.Binary =>
      load_bytes(env, drop_bom(bytes_from(series, index)), header, all)
    _ => load_bytes(env, utf8_bytes(source_text(source)), header, all)
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
/// %.txt and %.cgi are the text codec, as in base-defs.reb.
fn text_file(source : @value.Cell) -> Bool raise EvalError {
  let name = file_suffix(source)
  name == ".txt" || name == ".cgi"
}

///|
/// Markup suffixes from base-defs.reb. The native codec cannot encode them.
/// %.json is the JSON codec, as in codec-json.reb.
fn json_file(source : @value.Cell) -> Bool raise EvalError {
  file_suffix(source) == ".json"
}

///|
/// %.gz is gzip, as in codec-gzip.reb. The payload is raw bytes, not text.
fn gzip_file(source : @value.Cell) -> Bool raise EvalError {
  file_suffix(source) == ".gz"
}

///|
/// %.tar is a ustar archive, as in codec-tar.reb. There is no encoder.
fn tar_suffix(source : @value.Cell) -> Bool raise EvalError {
  file_suffix(source) == ".tar"
}

///|
/// Suffixes from codec-zip.reb. A save stores one file, uncompressed.
fn zip_suffix(source : @value.Cell) -> Bool raise EvalError {
  match file_suffix(source) {
    ".zip"
    | ".aar"
    | ".jar"
    | ".apk"
    | ".zipx"
    | ".appx"
    | ".epub"
    | ".docx"
    | ".swc" => true
    _ => false
  }
}

///|
fn markup_file(source : @value.Cell) -> Bool raise EvalError {
  match file_suffix(source) {
    ".html" | ".htm" | ".xsl" | ".wml" | ".sgml" | ".asp" | ".php" => true
    _ => false
  }
}

///|
fn file_suffix(source : @value.Cell) -> String raise EvalError {
  match source {
    @value.Seq(series, _) if series.datatype() == @value.File =>
      match perform_suffix(source) {
        @value.Seq(named, index) => text_from(named, index).to_lower()
        _ => ""
      }
    _ => ""
  }
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
      let path = text_from(series, index)
      if gzip_file(place) && !named(env, active, "header") {
        write_binary(path, gzip_saved(args[1]))
        return place
      }
      if tar_suffix(place) && !named(env, active, "header") {
        raise EvalError::Caused("not-done", "tar")
      }
      if zip_suffix(place) && !named(env, active, "header") {
        write_binary(path, zip_saved(args[1]))
        return place
      }
      if markup_file(place) && !named(env, active, "header") {
        raise EvalError::Caused("invalid-arg", @mold.mold_text(args[1]))
      }
      let body = if text_file(place) && !named(env, active, "header") {
        encoded_text(args[1])
      } else if json_file(place) && !named(env, active, "header") {
        encoded_json(args[1])
      } else {
        script
      }
      write_file(path, body)
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
/// `'script` molds that payload as base 64. `/header` supplies the fields.
fn save_bytes(
  env : Env,
  script : String,
  active : Array[Int],
  args : Array[@value.Cell],
) -> Array[Int] raise EvalError {
  let (mode, length, spec) = save_mode(env, active, args)
  let header = match spec {
    Some(given) => given
    None => @value.Seq(@value.Series::block(), 0)
  }
  if length || spec is Some(_) {
    save_with_header(env, script, header, mode, length)
  } else {
    match mode {
      None => utf8_bytes(script)
      Some(chosen) => save_compressed(env, script, chosen)
    }
  }
}

///|
fn save_mode(
  env : Env,
  active : Array[Int],
  args : Array[@value.Cell],
) -> (@value.Cell?, Bool, @value.Cell?) raise EvalError {
  let mut mode : @value.Cell? = None
  let mut length = false
  let mut spec : @value.Cell? = None
  let mut cursor = 2
  for sym in active {
    let name = env.symbols.canon(sym)
    if name == "compress" {
      mode = Some(args[cursor])
      cursor = cursor + 1
    } else if name == "length" {
      length = true
    } else if name == "header" {
      spec = Some(args[cursor])
      cursor = cursor + 1
    } else {
      raise EvalError::Cannot("save")
    }
  }
  (mode, length, spec)
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
