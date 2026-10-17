///|
/// A port keeps the spec object, the scheme object, and the scheme name used
/// to pick an actor. Two ports are the same only when they are one value.
pub struct PortValue {
  spec : Frame
  scheme : Frame
  name : String
  mut opened : Bool
}

///|
pub fn PortValue::make(
  spec : Frame,
  scheme : Frame,
  name : String,
) -> PortValue {
  { spec, scheme, name, opened: false, }
}

///|
pub fn PortValue::set_opened(self : PortValue, flag : Bool) -> Unit {
  self.opened = flag
}

///|
pub fn PortValue::is_open(self : PortValue) -> Bool {
  self.opened
}
