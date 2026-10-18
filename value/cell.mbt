///|
pub(all) enum Cell {
  Unset
  None
  Logic(Bool)
  Integer(Int64)
  Decimal(Double)
  Percent(Double)
  Pair(Int64, Int64)
  Tuple(Array[Int])
  Money(Double)
  Time(Double)
  Date(DateValue)
  Char(Int)
  Sym(Datatype, Lexeme)
  Seq(Series, Int)
  Type(Datatype)
  Function(Func)
  Object(Frame)
  Error(ErrorValue)
  Bitset(Bitset)
  Map(MapValue)
  Module(ModuleValue)
  Port(PortValue)
  Handle(HandleValue)
  Vector(Vector)
  Image(Image)
}

///|
pub fn Cell::datatype(self : Cell) -> Datatype {
  match self {
    Unset => Unset
    None => None
    Logic(_) => Logic
    Integer(_) => Integer
    Decimal(_) => Decimal
    Percent(_) => Percent
    Pair(_, _) => Pair
    Tuple(_) => Tuple
    Money(_) => Money
    Time(_) => Time
    Date(_) => Date
    Char(_) => Char
    Sym(datatype, _) => datatype
    Seq(series, _) => series.datatype()
    Type(_) => Datatype
    Function(func) =>
      if func.is_closure() {
        Closure
      } else if func.infix {
        Op
      } else {
        Function
      }
    Object(_) => Object
    Error(_) => Error
    Bitset(_) => Bitset
    Map(_) => Map
    Module(_) => Module
    Port(_) => Port
    Handle(_) => Handle
    Vector(_) => Vector
    Image(_) => Image
  }
}

///|
pub fn Cell::index(self : Cell) -> Int? {
  match self {
    Seq(_, index) => Some(index)
    _ => None
  }
}

///|
pub fn Cell::series(self : Cell) -> Series? {
  match self {
    Seq(series, _) => Some(series)
    _ => None
  }
}

///|
/// Copies the cell. A series copy keeps the same buffer and its own index.
/// A word copy is a new lexeme with the binding as it is now.
pub fn Cell::snapshot(self : Cell) -> Cell {
  match self {
    Sym(datatype, lexeme) => Sym(datatype, lexeme.snapshot())
    _ => self
  }
}
