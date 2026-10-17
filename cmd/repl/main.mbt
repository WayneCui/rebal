///|
fn main {
  let args = @env.args()
  if args.length() == 0 {
    println("Usage: moon run cmd/repl -- \"x: 1 + 2\"")
  } else {
    let source = args[args.length() - 1]
    let env = @eval.Env::new()
    try {
      let cell = @eval.run(env, source)
      println(@mold.mold_text(cell))
    } catch {
      error => println(@mold.mold_text(error.to_cell()))
    }
  }
}
