///|
pub struct Env {
  symbols : @value.Symbols
  user : @value.Frame
}

///|
let native_add : Int = 1

///|
let native_subtract : Int = 2

///|
let native_multiply : Int = 3

///|
let native_append : Int = 4

///|
let native_find : Int = 5

///|
let native_pick : Int = 6

///|
let native_length : Int = 7

///|
let native_first : Int = 8

///|
let native_copy : Int = 9

///|
let native_insert : Int = 10

///|
let native_remove : Int = 11

///|
let native_func : Int = 12

///|
let native_does : Int = 13

///|
let native_make : Int = 14

///|
let native_reduce : Int = 15

///|
let native_do : Int = 16

///|
pub fn Env::new() -> Env {
  let env = Env::{ symbols: @value.Symbols::new(), user: @value.Frame::new(), }
  install(env, "true", @value.Logic(true))
  install(env, "false", @value.Logic(false))
  install(env, "none", @value.None)
  define_native(env, "+", 2, true, native_add)
  define_native(env, "-", 2, true, native_subtract)
  define_native(env, "*", 2, true, native_multiply)
  define_native(env, "append", 2, false, native_append)
  define_native(env, "find", 2, false, native_find)
  define_native(env, "pick", 2, false, native_pick)
  define_native(env, "length?", 1, false, native_length)
  define_native(env, "first", 1, false, native_first)
  define_native(env, "copy", 1, false, native_copy)
  define_native(env, "insert", 2, false, native_insert)
  define_native(env, "remove", 1, false, native_remove)
  define_native(env, "func", 2, false, native_func)
  define_native(env, "does", 1, false, native_does)
  define_native(env, "make", 2, false, native_make)
  define_native(env, "reduce", 1, false, native_reduce)
  define_native(env, "do", 1, false, native_do)
  install(env, "object!", @value.Type(@value.Object))
  env
}

///|
fn install(env : Env, spelling : String, cell : @value.Cell) -> Unit {
  let sym = env.symbols.intern(spelling)
  let slot = env.user.ensure(sym)
  env.user.set(slot, cell)
}

///|
fn define_native(
  env : Env,
  spelling : String,
  arity : Int,
  infix : Bool,
  code : Int,
) -> Unit {
  install(
    env,
    spelling,
    @value.Function(@value.Func::native(arity, infix, code)),
  )
}

///|
/// Transcodes `source` and binds words that already have a user slot.
pub fn load(env : Env, source : String) -> @value.Cell raise EvalError {
  match @scan.transcode(source, env.symbols) {
    Ok(cell) => @bind.bind(cell, env.user)
    Err(error) => raise EvalError::BadSource(error.id())
  }
}
