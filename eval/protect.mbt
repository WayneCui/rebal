///|
/// Locks or unlocks the word in the frame it is already bound to.
/// An unbound word is locked in the user context.
fn perform_protect(
  env : Env,
  word : @value.Cell,
  flag : Bool,
) -> @value.Cell raise EvalError {
  let name = if flag { "protect" } else { "unprotect" }
  let lexeme = as_word(word, name)
  let (frame, slot) = bound_slot(env, lexeme)
  frame.lock(slot, flag)
  word
}

///|
fn perform_protected_q(
  env : Env,
  word : @value.Cell,
) -> @value.Cell raise EvalError {
  let lexeme = as_word(word, "protected?")
  let flag = match lexeme.binding() {
    @value.Bound(frame, slot) => frame.is_locked(slot)
    @value.Unbound =>
      match env.user.find(lexeme.sym()) {
        Some(slot) => env.user.is_locked(slot)
        None => false
      }
  }
  @value.Logic(flag)
}

///|
fn bound_slot(env : Env, lexeme : @value.Lexeme) -> (@value.Frame, Int) {
  match lexeme.binding() {
    @value.Bound(frame, slot) => (frame, slot)
    @value.Unbound => {
      let slot = env.user.ensure(lexeme.sym())
      (env.user, slot)
    }
  }
}
