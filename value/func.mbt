///|
pub struct Func {
  params : Array[Int]
  body : Series
  infix : Bool
  code : Int
}

///|
/// `code` 0 evaluates `body`. Any other code is a native action.
pub fn Func::make(params : Array[Int], body : Series, infix : Bool) -> Func {
  { params, body, infix, code: 0, }
}

///|
pub fn Func::native(arity : Int, infix : Bool, code : Int) -> Func {
  let params : Array[Int] = []
  for _ in 0..<arity {
    params.push(0)
  }
  { params, body: Series::block(), infix, code, }
}

///|
pub fn Func::arity(self : Func) -> Int {
  self.params.length()
}

///|
pub fn Func::is_infix(self : Func) -> Bool {
  self.infix
}

///|
pub fn Func::code(self : Func) -> Int {
  self.code
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
