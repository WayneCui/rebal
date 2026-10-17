///|
pub struct Func {
  params : Array[Int]
  types : Array[Array[Datatype]]
  refines : Array[Int]
  refine_args : Array[Array[Int]]
  body : Series
  infix : Bool
  code : Int
  frame : Frame
  closure : Bool
}

///|
/// `code` 0 evaluates `body` in `frame`. Any other code is a native action.
pub fn Func::make(
  params : Array[Int],
  types : Array[Array[Datatype]],
  refines : Array[Int],
  refine_args : Array[Array[Int]],
  body : Series,
  infix : Bool,
  frame : Frame,
  closure : Bool,
) -> Func {
  { params, types, refines, refine_args, body, infix, code: 0, frame, closure, }
}

///|
pub fn Func::native(arity : Int, infix : Bool, code : Int) -> Func {
  let params : Array[Int] = []
  for _ in 0..<arity {
    params.push(0)
  }
  {
    params,
    types: [],
    refines: [],
    refine_args: [],
    body: Series::block(),
    infix,
    code,
    frame: Frame::new(),
    closure: false,
  }
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
pub fn Func::is_closure(self : Func) -> Bool {
  self.closure
}

///|
pub fn Func::code(self : Func) -> Int {
  self.code
}

///|
pub fn Func::params(self : Func) -> Array[Int] {
  self.params
}

///|
pub fn Func::types(self : Func) -> Array[Array[Datatype]] {
  self.types
}

///|
pub fn Func::refines(self : Func) -> Array[Int] {
  self.refines
}

///|
pub fn Func::refine_args(self : Func) -> Array[Array[Int]] {
  self.refine_args
}

///|
pub fn Func::body(self : Func) -> Series {
  self.body
}

///|
pub fn Func::frame(self : Func) -> Frame {
  self.frame
}

///|
/// Same function, evaluated between two values.
pub fn Func::as_op(self : Func) -> Func {
  {
    params: self.params,
    types: self.types,
    refines: self.refines,
    refine_args: self.refine_args,
    body: self.body,
    infix: true,
    code: self.code,
    frame: self.frame,
    closure: self.closure,
  }
}

///|
pub struct ErrorValue {
  id : String
  arg1 : String
  near : String
}

///|
pub fn ErrorValue::make(
  id : String,
  arg1 : String,
  near : String,
) -> ErrorValue {
  { id, arg1, near, }
}
