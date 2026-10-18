///|
/// One pixel is `r + g << 8 + b << 16 + a << 24`. A new image is white.
pub struct Image {
  width : Int
  height : Int
  pixels : Array[Int]
}

///|
pub fn Image::white(width : Int, height : Int) -> Image {
  let pixels : Array[Int] = []
  let count = width * height
  for _ in 0..<count {
    pixels.push(pack(255, 255, 255, 255))
  }
  { width, height, pixels, }
}

///|
pub fn Image::width(self : Image) -> Int {
  self.width
}

///|
pub fn Image::height(self : Image) -> Int {
  self.height
}

///|
pub fn Image::length(self : Image) -> Int {
  self.pixels.length()
}

///|
pub fn Image::fill_tuple(self : Image, parts : Array[Int]) -> Unit {
  let red = part_at(parts, 0)
  let green = part_at(parts, 1)
  let blue = part_at(parts, 2)
  let alpha = if parts.length() > 3 { part_at(parts, 3) } else { 255 }
  for index in 0..<self.pixels.length() {
    let kept = if parts.length() > 3 {
      alpha
    } else {
      (self.pixels[index] >> 24) & 255
    }
    self.pixels[index] = pack(red, green, blue, kept)
  }
}

///|
pub fn Image::fill_alpha(self : Image, alpha : Int) -> Unit {
  let byte = alpha & 255
  for index in 0..<self.pixels.length() {
    let pixel = self.pixels[index]
    self.pixels[index] = pack(
      pixel & 255,
      (pixel >> 8) & 255,
      (pixel >> 16) & 255,
      byte,
    )
  }
}

///|
/// RGB bytes come in groups of three. A short buffer leaves the rest white.
pub fn Image::load_rgb(self : Image, bytes : Array[Int]) -> Unit {
  let groups = bytes.length() / 3
  let limit = if groups < self.pixels.length() {
    groups
  } else {
    self.pixels.length()
  }
  for index in 0..<limit {
    let alpha = (self.pixels[index] >> 24) & 255
    self.pixels[index] = pack(
      bytes[index * 3],
      bytes[index * 3 + 1],
      bytes[index * 3 + 2],
      alpha,
    )
  }
}

///|
pub fn Image::load_alpha(self : Image, bytes : Array[Int]) -> Unit {
  let limit = if bytes.length() < self.pixels.length() {
    bytes.length()
  } else {
    self.pixels.length()
  }
  for index in 0..<limit {
    let pixel = self.pixels[index]
    self.pixels[index] = pack(
      pixel & 255,
      (pixel >> 8) & 255,
      (pixel >> 16) & 255,
      bytes[index],
    )
  }
}

///|
pub fn Image::has_alpha(self : Image) -> Bool {
  let mut found = false
  for pixel in self.pixels {
    if ((pixel >> 24) & 255) != 255 {
      found = true
    }
  }
  found
}

///|
pub fn Image::tuple_at(self : Image, index : Int) -> Cell? {
  if index < 1 || index > self.pixels.length() {
    None
  } else {
    Some(tuple_of(self.pixels[index - 1]))
  }
}

///|
/// Pair positions are 1-based. A column past the width continues on the next row.
pub fn Image::tuple_at_xy(self : Image, x : Int, y : Int) -> Cell? {
  if x < 1 || y < 1 {
    None
  } else {
    self.tuple_at((y - 1) * self.width + x)
  }
}

///|
pub fn Image::channel_bytes(self : Image, kind : String) -> Array[Int] {
  let out : Array[Int] = []
  for pixel in self.pixels {
    let red = pixel & 255
    let green = (pixel >> 8) & 255
    let blue = (pixel >> 16) & 255
    let alpha = (pixel >> 24) & 255
    if kind == "rgba" {
      out.push(red)
      out.push(green)
      out.push(blue)
      out.push(alpha)
    } else if kind == "alpha" {
      out.push(alpha)
    } else {
      out.push(red)
      out.push(green)
      out.push(blue)
    }
  }
  out
}

///|
pub fn Image::same(self : Image, other : Image) -> Bool {
  if self.width != other.width ||
    self.height != other.height ||
    self.pixels.length() != other.pixels.length() {
    false
  } else {
    let mut ok = true
    for index in 0..<self.pixels.length() {
      if self.pixels[index] != other.pixels[index] {
        ok = false
      }
    }
    ok
  }
}

///|
fn tuple_of(pixel : Int) -> Cell {
  Tuple([
    pixel & 255,
    (pixel >> 8) & 255,
    (pixel >> 16) & 255,
    (pixel >> 24) & 255,
  ])
}

///|
fn pack(red : Int, green : Int, blue : Int, alpha : Int) -> Int {
  (red & 255) +
  ((green & 255) << 8) +
  ((blue & 255) << 16) +
  ((alpha & 255) << 24)
}

///|
fn part_at(parts : Array[Int], index : Int) -> Int {
  if index < parts.length() {
    parts[index] & 255
  } else {
    0
  }
}
