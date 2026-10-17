///|
/// Nearest nanosecond. Rebol stores a time in whole nanoseconds.
pub fn snap_seconds(seconds : Double) -> Double {
  let scaled = seconds * 1000000000.0
  let negative = scaled < 0.0
  let magnitude = if negative { 0.0 - scaled } else { scaled }
  let rounded = (magnitude + 0.5).to_int64()
  let nanos = if negative { 0L - rounded } else { rounded }
  nanos.to_double() / 1000000000.0
}
