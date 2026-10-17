///|
/// A module keeps its own frame. `exports` names the words `import` copies out.
pub struct ModuleValue {
  frame : Frame
  exports : Array[Int]
}

///|
pub fn ModuleValue::make(frame : Frame, exports : Array[Int]) -> ModuleValue {
  { frame, exports, }
}
