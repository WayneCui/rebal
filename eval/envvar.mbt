///|
#borrow(name)
extern "C" fn c_get_env(name : String, name_len : Int) -> String = "rebal_get_env"

///|
extern "C" fn c_env_found() -> Int = "rebal_env_found"

///|
#borrow(name, value)
extern "C" fn c_set_env(
  name : String,
  name_len : Int,
  value : String,
  value_len : Int,
) -> Int = "rebal_set_env"

///|
/// The value of an environment variable, or `none` when it is unset.
fn perform_get_env(name : @value.Cell) -> @value.Cell raise EvalError {
  match name {
    @value.Seq(series, index) if series.datatype() == @value.String ||
      series.datatype() == @value.File ||
      series.datatype() == @value.Url => {
      let text = text_from(series, index)
      let value = c_get_env(text, text.length())
      if c_env_found() == 0 {
        let out = @value.Series::text_of(@value.String)
        for char in value {
          out.push_code(char.to_int()) |> ignore
        }
        @value.Seq(out, 0)
      } else {
        @value.None
      }
    }
    @value.None => @value.None
    _ => raise EvalError::Cannot("get-env")
  }
}

///|
/// Sets an environment variable and returns its new value.
fn perform_set_env(
  name : @value.Cell,
  value : @value.Cell,
) -> @value.Cell raise EvalError {
  match name {
    @value.Seq(series, index) if series.datatype() == @value.String ||
      series.datatype() == @value.File ||
      series.datatype() == @value.Url => {
      let key = text_from(series, index)
      let text = match value {
        @value.Seq(vseries, vindex) if vseries.datatype() == @value.String ||
          vseries.datatype() == @value.File ||
          vseries.datatype() == @value.Url => text_from(vseries, vindex)
        @value.None => ""
        _ => raise EvalError::Cannot("set-env")
      }
      if c_set_env(key, key.length(), text, text.length()) == 0 {
        value
      } else {
        raise EvalError::Cannot("set-env")
      }
    }
    _ => raise EvalError::Cannot("set-env")
  }
}
