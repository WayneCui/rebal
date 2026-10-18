///|
pub struct Func {
  params : Array[Int]
  types : Array[Array[Datatype]]
  lits : Array[Bool]
  refines : Array[Int]
  refine_args : Array[Array[Int]]
  spec_words : Array[Int]
  spec_kinds : Array[Int]
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
  lits : Array[Bool],
  refines : Array[Int],
  refine_args : Array[Array[Int]],
  spec_words : Array[Int],
  spec_kinds : Array[Int],
  body : Series,
  infix : Bool,
  frame : Frame,
  closure : Bool,
) -> Func {
  {
    params,
    types,
    lits,
    refines,
    refine_args,
    spec_words,
    spec_kinds,
    body,
    infix,
    code: 0,
    frame,
    closure,
  }
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
    lits: [],
    refines: [],
    refine_args: [],
    spec_words: [],
    spec_kinds: [],
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
/// Parallel to `params`. True means that argument is taken without evaluation.
pub fn Func::lits(self : Func) -> Array[Bool] {
  self.lits
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
/// Spec words in source order. Kinds are 0 for a word, 1 for a refinement,
/// and 2 for a lit-word.
pub fn Func::spec_words(self : Func) -> Array[Int] {
  self.spec_words
}

///|
pub fn Func::spec_kinds(self : Func) -> Array[Int] {
  self.spec_kinds
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
    lits: self.lits,
    refines: self.refines,
    refine_args: self.refine_args,
    spec_words: self.spec_words,
    spec_kinds: self.spec_kinds,
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
