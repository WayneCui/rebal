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
} derive(Eq)

///|
pub extend Datatype with Eq::{not_equal, equal}
