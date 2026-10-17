///|
test "not and or treat only false and none as false" {
  assert_true(@action.logic_not(@value.Logic(false)) is @value.Logic(true))
  assert_true(@action.logic_not(@value.None) is @value.Logic(true))
  assert_true(@action.logic_not(@value.Integer(1L)) is @value.Logic(false))
  assert_true(
    @action.logic_and(@value.Integer(1L), @value.Integer(2L))
    is @value.Logic(true),
  )
  assert_true(
    @action.logic_or(@value.Logic(false), @value.None) is @value.Logic(false),
  )
}
