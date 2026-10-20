///|
/// How a TCP port behaves under `wait`.
pub enum PortKind {
  TcpSync
  TcpListen
  TcpAsync
}

///|
pub fn PortKind::tcp_sync() -> PortKind {
  TcpSync
}

///|
pub fn PortKind::tcp_listen() -> PortKind {
  TcpListen
}

///|
pub fn PortKind::tcp_async() -> PortKind {
  TcpAsync
}

///|
/// A port keeps the spec object, the scheme object, and the scheme name used
/// to pick an actor. Two ports are the same only when they are one value.
/// Listen/async TCP ports also keep `awake`, `data`, and an accept queue.
pub struct PortValue {
  spec : Frame
  scheme : Frame
  name : String
  mut opened : Bool
  mut handle : Int
  mut kind : PortKind
  mut awake : Cell
  mut data : Cell
  mut accepts : Array[Cell]
  mut want_read : Bool
  mut pending_wrote : Bool
}

///|
pub fn PortValue::make(
  spec : Frame,
  scheme : Frame,
  name : String,
) -> PortValue {
  {
    spec,
    scheme,
    name,
    opened: false,
    handle: -1,
    kind: TcpSync,
    awake: Cell::Unset,
    data: Cell::None,
    accepts: [],
    want_read: false,
    pending_wrote: false,
  }
}

///|
pub fn PortValue::set_opened(self : PortValue, flag : Bool) -> Unit {
  self.opened = flag
}

///|
pub fn PortValue::is_open(self : PortValue) -> Bool {
  self.opened
}

///|
pub fn PortValue::set_handle(self : PortValue, handle : Int) -> Unit {
  self.handle = handle
}

///|
pub fn PortValue::handle(self : PortValue) -> Int {
  self.handle
}

///|
pub fn PortValue::set_kind(self : PortValue, kind : PortKind) -> Unit {
  self.kind = kind
}

///|
pub fn PortValue::kind(self : PortValue) -> PortKind {
  self.kind
}

///|
pub fn PortValue::set_awake(self : PortValue, cell : Cell) -> Unit {
  self.awake = cell
}

///|
pub fn PortValue::awake(self : PortValue) -> Cell {
  self.awake
}

///|
pub fn PortValue::set_data(self : PortValue, cell : Cell) -> Unit {
  self.data = cell
}

///|
pub fn PortValue::data(self : PortValue) -> Cell {
  self.data
}

///|
pub fn PortValue::push_accept(self : PortValue, cell : Cell) -> Unit {
  self.accepts.push(cell)
}

///|
pub fn PortValue::take_accept(self : PortValue) -> Cell? {
  if self.accepts.length() == 0 {
    None
  } else {
    let cell = self.accepts[0]
    let rest : Array[Cell] = []
    for i in 1..<self.accepts.length() {
      rest.push(self.accepts[i])
    }
    self.accepts = rest
    Some(cell)
  }
}

///|
pub fn PortValue::set_want_read(self : PortValue, flag : Bool) -> Unit {
  self.want_read = flag
}

///|
pub fn PortValue::want_read(self : PortValue) -> Bool {
  self.want_read
}

///|
pub fn PortValue::set_pending_wrote(self : PortValue, flag : Bool) -> Unit {
  self.pending_wrote = flag
}

///|
pub fn PortValue::pending_wrote(self : PortValue) -> Bool {
  self.pending_wrote
}
