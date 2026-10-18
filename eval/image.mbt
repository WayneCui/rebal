///|
/// `make image! 2x2` is white. A block is `[size rgb alpha]`.
/// A bare pair larger than 65535 on either side is `size-limit`.
/// A block that is not that shape is `malconstruct`.
fn make_image(spec : @value.Cell) -> @value.Cell raise EvalError {
  match spec {
    @value.Pair(x, y) => image_sized(x, y, true)
    @value.Seq(series, index) if series.datatype() == @value.Block =>
      image_block(series, index)
    _ => raise EvalError::Caused("malconstruct", "")
  }
}

///|
fn image_sized(
  x : Int64,
  y : Int64,
  clamp : Bool,
) -> @value.Cell raise EvalError {
  if x > 65535L || y > 65535L {
    if clamp {
      raise EvalError::Caused("size-limit", "image!")
    } else {
      raise EvalError::Caused("malconstruct", "")
    }
  }
  if x < 0L || y < 0L {
    if clamp {
      let width = if x < 0L { 0 } else { x.to_int() }
      let height = if y < 0L { 0 } else { y.to_int() }
      @value.Image(@value.Image::white(width, height))
    } else {
      raise EvalError::Caused("malconstruct", "")
    }
  } else {
    @value.Image(@value.Image::white(x.to_int(), y.to_int()))
  }
}

///|
fn image_block(
  series : @value.Series,
  index : Int,
) -> @value.Cell raise EvalError {
  let items : Array[@value.Cell] = []
  for cursor in index..<series.length() {
    match series.item(cursor) {
      Some(item) => items.push(item)
      None => ()
    }
  }
  if items.length() == 0 {
    raise EvalError::Caused("malconstruct", "")
  }
  match items[0] {
    @value.Pair(x, y) => {
      let image = image_sized(x, y, false)
      match image {
        @value.Image(pixels) => image_rest(pixels, items)
        _ => image
      }
    }
    _ => raise EvalError::Caused("malconstruct", "")
  }
}

///|
fn image_rest(
  image : @value.Image,
  items : Array[@value.Cell],
) -> @value.Cell raise EvalError {
  if items.length() == 1 {
    @value.Image(image)
  } else {
    match items[1] {
      @value.Seq(series, index) if series.datatype() == @value.Binary => {
        image.load_rgb(image_bytes(series, index))
        let mut cursor = 2
        if cursor < items.length() {
          match items[cursor] {
            @value.Seq(alpha, alpha_index) if alpha.datatype() == @value.Binary => {
              image.load_alpha(image_bytes(alpha, alpha_index))
              cursor = cursor + 1
            }
            _ => ()
          }
        }
        if cursor < items.length() {
          match items[cursor] {
            @value.Integer(_) => cursor = cursor + 1
            _ => ()
          }
        }
        if cursor == items.length() {
          @value.Image(image)
        } else {
          raise EvalError::Caused("malconstruct", "")
        }
      }
      @value.Tuple(parts) => {
        image.fill_tuple(parts)
        if items.length() == 2 {
          @value.Image(image)
        } else if items.length() == 3 {
          match items[2] {
            @value.Integer(alpha) => {
              image.fill_alpha(alpha.to_int())
              @value.Image(image)
            }
            _ => raise EvalError::Caused("malconstruct", "")
          }
        } else {
          raise EvalError::Caused("malconstruct", "")
        }
      }
      _ => raise EvalError::Caused("malconstruct", "")
    }
  }
}

///|
fn image_bytes(series : @value.Series, index : Int) -> Array[Int] {
  let bytes : Array[Int] = []
  for cursor in index..<series.length() {
    match series.byte_at(cursor) {
      Some(byte) => bytes.push(byte.to_int())
      None => ()
    }
  }
  bytes
}

///|
fn image_binary(bytes : Array[Int]) -> @value.Cell {
  let series = @value.Series::binary()
  for byte in bytes {
    let _ = series.push_byte(byte.to_byte())
  }
  @value.Seq(series, 0)
}

///|
fn image_field(
  env : Env,
  image : @value.Image,
  selector : @value.Cell,
) -> @value.Cell raise EvalError {
  match selector {
    @value.Integer(index) =>
      match image.tuple_at(index.to_int()) {
        Some(pixel) => pixel
        None => @value.Cell::None
      }
    @value.Pair(x, y) =>
      match image.tuple_at_xy(x.to_int(), y.to_int()) {
        Some(pixel) => pixel
        None => @value.Cell::None
      }
    @value.Logic(flag) =>
      match image.tuple_at(if flag { 1 } else { 2 }) {
        Some(pixel) => pixel
        None => @value.Cell::None
      }
    @value.Sym(_, lexeme) => {
      let name = env.symbols.canon(lexeme.sym())
      if name == "size" {
        @value.Pair(image.width().to_int64(), image.height().to_int64())
      } else if name == "width" {
        @value.Integer(image.width().to_int64())
      } else if name == "height" {
        @value.Integer(image.height().to_int64())
      } else if name == "rgb" {
        image_binary(image.channel_bytes("rgb"))
      } else if name == "rgba" {
        image_binary(image.channel_bytes("rgba"))
      } else if name == "alpha" {
        image_binary(image.channel_bytes("alpha"))
      } else {
        raise EvalError::InvalidPath(lexeme.spelling())
      }
    }
    _ => raise EvalError::InvalidPath("image")
  }
}
