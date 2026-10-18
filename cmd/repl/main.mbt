///|
extern "C" fn c_getchar() -> Int = "getchar"

///|
extern "C" fn c_putchar(code : Int) -> Int = "putchar"

///|
extern "C" fn c_flush_stdout() -> Unit = "rebal_flush_stdout"

///|
fn main {
  let args = @env.args()
  // args[0] is the executable path. A source appears only after it.
  if args.length() <= 1 {
    session()
  } else {
    once(args[args.length() - 1])
  }
}

///|
fn once(source : String) -> Unit {
  match once_reply(source) {
    Some(text) => println(text)
    None => ()
  }
}

///|
/// Text a one-shot script would print. `None` is `quit`: print nothing and exit.
fn once_reply(source : String) -> String? {
  let env = @eval.Env::new()
  Some(@mold.mold_text(@eval.run(env, source))) catch {
    @eval.Quit => None
    error => Some(@mold.mold_text(error.to_cell()))
  }
}

///|
fn session() -> Unit {
  let env = @eval.Env::new()
  let mut pending = ""
  let mut reading = true
  while reading {
    write_text(prompt_text(pending))
    c_flush_stdout()
    match read_line() {
      None =>
        match finish_reply(env, pending) {
          Keep(text, _) => {
            if text != "" {
              println(text)
            }
            reading = false
          }
          Halt => reading = false
        }
      Some(line) =>
        match line_reply(env, pending, line) {
          Keep(text, rest) => {
            if text != "" {
              println(text)
            }
            pending = rest
          }
          Halt => reading = false
        }
    }
  }
}

///|
fn read_line() -> String? {
  let buf = StringBuilder()
  let mut any = false
  let mut open = true
  let mut eof = false
  while open {
    let code = c_getchar()
    if code < 0 {
      eof = true
      open = false
    } else if code == '\n'.to_int() {
      any = true
      open = false
    } else if code != '\r'.to_int() {
      match code.to_char() {
        Some(char) => {
          buf.write_char(char)
          any = true
        }
        None => ()
      }
    }
  }
  if eof && !any {
    None
  } else {
    Some(buf.to_string())
  }
}

///|
fn write_text(text : String) -> Unit {
  for char in text {
    c_putchar(char.to_int()) |> ignore
  }
}
