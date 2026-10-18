///|
pub(all) enum Datatype {
  Unset
  None
  Logic
  Integer
  Decimal
  Percent
  Pair
  Tuple
  Money
  Time
  Date
  Char
  Word
  SetWord
  GetWord
  LitWord
  Refinement
  String
  File
  Email
  Url
  Tag
  Issue
  Binary
  Block
  Paren
  Path
  SetPath
  Datatype
  Function
  Op
  Object
  Error
  Bitset
  Map
  Module
  Closure
  Port
  Handle
  Vector
  Image
} derive(Eq)

///|
/// Character series: string, and the any-string types stored the same way.
pub fn text_series(datatype : Datatype) -> Bool {
  match datatype {
    String | File | Email | Url | Tag | Issue => true
    _ => false
  }
}

///|
pub extend Datatype with Eq::{not_equal, equal}
