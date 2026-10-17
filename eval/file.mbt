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
fn perform_load(env : Env, source : @value.Cell) -> @value.Cell raise EvalError {
  if pkix_file(source) {
    match read_pem(read_file(loaded_path(source))) {
      Some(pem) => pem_block(env, pem)
      None => @value.None
    }
  } else if key_file(source) {
    decode_ssh_key(env, text_series(read_file(loaded_path(source))))
  } else {
    singular(drop_header(load(env, source_text(source))))
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
/// %.key is an SSH key, as in codec-ssh-key.reb.
fn key_file(source : @value.Cell) -> Bool raise EvalError {
  match source {
    @value.Seq(series, _) if series.datatype() == @value.File =>
      match perform_suffix(source) {
        @value.Seq(suffix, index) =>
          text_from(suffix, index).to_lower() == ".key"
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
  place : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  match place {
    @value.Seq(series, index) if series.datatype() == @value.File => {
      write_file(text_from(series, index), @mold.mold_text(value) + "\n")
      place
    }
    _ => raise EvalError::Cannot("save")
  }
}

///|
fn source_text(source : @value.Cell) -> String raise EvalError {
  match source {
    @value.Seq(series, index) if series.datatype() == @value.String =>
      text_from(series, index)
    @value.Seq(series, index) if series.datatype() == @value.File =>
      read_file(text_from(series, index))
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
