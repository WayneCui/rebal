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
let native_mold : Int = 17

///|
let native_form : Int = 18

///|
let native_type : Int = 19

///|
let native_try : Int = 20

///|
let native_equal : Int = 21

///|
let native_not_equal : Int = 22

///|
let native_lesser : Int = 23

///|
let native_greater : Int = 24

///|
let native_if : Int = 25

///|
let native_either : Int = 26

///|
let native_return : Int = 27

///|
let native_while : Int = 28

///|
let native_until : Int = 29

///|
let native_loop : Int = 30

///|
let native_break : Int = 31

///|
let native_foreach : Int = 32

///|
let native_continue : Int = 33

///|
let native_not : Int = 34

///|
let native_and : Int = 35

///|
let native_or : Int = 36

///|
let native_any : Int = 37

///|
let native_all : Int = 38

///|
let native_case : Int = 39

///|
let native_switch : Int = 40

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
  define_native(env, "mold", 1, false, native_mold)
  define_native(env, "form", 1, false, native_form)
  define_native(env, "type?", 1, false, native_type)
  define_native(env, "try", 1, false, native_try)
  define_native(env, "=", 2, true, native_equal)
  define_native(env, "<>", 2, true, native_not_equal)
  define_native(env, "<", 2, true, native_lesser)
  define_native(env, ">", 2, true, native_greater)
  define_native(env, "if", 2, false, native_if)
  define_native(env, "either", 3, false, native_either)
  define_native(env, "return", 1, false, native_return)
  define_native(env, "while", 2, false, native_while)
  define_native(env, "until", 1, false, native_until)
  define_native(env, "loop", 2, false, native_loop)
  define_native(env, "break", 0, false, native_break)
  define_native(env, "foreach", 3, false, native_foreach)
  define_native(env, "continue", 0, false, native_continue)
  define_native(env, "not", 1, false, native_not)
  define_native(env, "and", 2, true, native_and)
  define_native(env, "or", 2, true, native_or)
  define_native(env, "any", 1, false, native_any)
  define_native(env, "all", 1, false, native_all)
  define_native(env, "case", 1, false, native_case)
  define_native(env, "switch", 2, false, native_switch)
  install(env, "unset!", @value.Type(@value.Unset))
  install(env, "none!", @value.Type(@value.None))
  install(env, "logic!", @value.Type(@value.Logic))
  install(env, "integer!", @value.Type(@value.Integer))
  install(env, "decimal!", @value.Type(@value.Decimal))
  install(env, "char!", @value.Type(@value.Char))
  install(env, "word!", @value.Type(@value.Word))
  install(env, "set-word!", @value.Type(@value.SetWord))
  install(env, "get-word!", @value.Type(@value.GetWord))
  install(env, "lit-word!", @value.Type(@value.LitWord))
  install(env, "refinement!", @value.Type(@value.Refinement))
  install(env, "string!", @value.Type(@value.String))
  install(env, "binary!", @value.Type(@value.Binary))
  install(env, "block!", @value.Type(@value.Block))
  install(env, "paren!", @value.Type(@value.Paren))
  install(env, "path!", @value.Type(@value.Path))
  install(env, "set-path!", @value.Type(@value.SetPath))
  install(env, "datatype!", @value.Type(@value.Datatype))
  install(env, "function!", @value.Type(@value.Function))
  install(env, "op!", @value.Type(@value.Op))
  install(env, "object!", @value.Type(@value.Object))
  install(env, "error!", @value.Type(@value.Error))
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
