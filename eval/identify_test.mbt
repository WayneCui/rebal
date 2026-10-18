///|
test "encoding? names zip, gzip, ar, der, pkix, or text" {
  // sys-codec.reb walks codecs from the last one registered.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(encoding? #{}) = 'text (encoding? #{6162}) = 'text (encoding? #{504B0304}) = 'text (encoding? #{504B030400}) = 'zip (encoding? next #{00504B030400}) = 'zip (encoding? #{1F8B08}) = 'text (encoding? #{1F8B00000000000000FF}) = 'text (encoding? #{1F8B08000000000000FF}) = 'gzip (encoding? #{30}) = 'der (encoding? #{00}) = 'text (encoding? #{213C617263683E0A}) = 'ar (encoding? #{213C617263683E}) = 'text (encoding? #{2D2D2D2D2D424547494E2043455254494649434154452D2D2D2D2D}) = 'text (encoding? #{2D2D2D2D2D424547494E2043455254494649434154452D2D2D2D2D0A}) = 'pkix (encoding? #{2D2D2D2D2D424547494E2043455254494649434154452D2D2D2D2D0D0A}) = 'pkix (encoding? #{2D2D2D2D2D424547494E2043455254494649434154452D2D2D2D2D0D}) = 'text (encoding? #{2D2D2D2D20424547494E20582D2D2D2D0A}) = 'pkix (encoding? #{2D2D2D2D2D424547494E20582D2D2D2D2D0A4D4F5245}) = 'pkix (encoding? #{6162630A2D2D2D2D2D424547494E20582D2D2D2D2D0A}) = 'pkix (encoding? #{2D6162632D2D2D2D2D424547494E20582D2D2D2D2D0A}) = 'text (type? try [encoding? \"ab\"]) = error!]) = reduce [true true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
