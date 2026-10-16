///|
pub struct Func {
  params : Array[Int]
  body : Series
  infix : Bool
}

///|
pub fn Func::make(params : Array[Int], body : Series, infix : Bool) -> Func {
  { params, body, infix, }
}

///|
pub struct ErrorValue {
  id : Int
  arg1 : String
  near : String
}

///|
pub fn ErrorValue::make(id : Int, arg1 : String, near : String) -> ErrorValue {
  { id, arg1, near, }
}
