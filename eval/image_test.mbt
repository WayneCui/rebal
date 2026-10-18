///|
test "image make fills pixels and molds rgb with alpha" {
  // t-image.c. A pair is white. A tuple fills every pixel. Alpha is a
  // separate binary when any pixel is not opaque. Ten pixels start a new line.
  let env = @eval.Env::new()
  let wide = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
  assert_true(
    @eval.run(
      env,
      "img: make image! 2x2 red: make image! [2x2 255.0.0] (reduce [(mold img) = {make image! [2x2 #{FFFFFFFFFFFFFFFFFFFFFFFF}]} (mold make image! 0x0) = {make image! [0x0 #{}]} (mold make image! 2x0) = {make image! [2x0 #{}]} (mold make image! -1x2) = {make image! [0x2 #{}]} (mold red) = {make image! [2x2 #{FF0000FF0000FF0000FF0000}]} (mold make image! [1x1 20.20.20.60]) = {make image! [1x1 #{141414} #{3C}]} (mold make image! [1x1 #{010203}]) = {make image! [1x1 #{010203}]} (mold make image! [1x1 #{010203} #{04}]) = {make image! [1x1 #{010203} #{04}]} (mold make image! [1x1 #{FF}]) = {make image! [1x1 #{FFFFFF}]} (mold make image! [1x1 20.20.20 60]) = {make image! [1x1 #{141414} #{3C}]} (mold make image! 1x10) = {make image! [1x10 #{\n" +
      wide +
      "\n}]} (mold make image! 1x11) = {make image! [1x11 #{\n" +
      wide +
      "\nFFFFFF\n}]} red/1 = 255.0.0.255 (pick red 2x1) = 255.0.0.255 none? red/5 none? pick red 0x1 (make image! 2x3)/size = 2x3 (make image! 2x3)/width = 2 (make image! 2x3)/height = 3 (make image! [1x1 1.2.3.4])/rgb = #{010203} (make image! [1x1 1.2.3.4])/rgba = #{01020304} (make image! [1x1 1.2.3.4])/alpha = #{04} (length? make image! 2x3) = 6 (make image! 1x1) = (make image! [1x1 255.255.255]) (make image! [1x1 1.2.3]) = (make image! [1x1 1.2.3.255]) (make image! 1x1) <> (make image! 1x2) (type? img) = image! (form make image! 1x1) = {make image! [1x1 #{FFFFFF}]} ((try [make image! 65536x1])/id) = 'size-limit ((try [make image! []])/id) = 'malconstruct ((try [make image! #{00000000}])/id) = 'malconstruct ((try [make image! [65536x1]])/id) = 'malconstruct]) = reduce [true true true true true true true true true true true true true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
