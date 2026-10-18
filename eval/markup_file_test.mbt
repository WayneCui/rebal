///|
test "xml and plist files load through their codecs" {
  // codec-xml.reb suffixes %.xml %.pom. codec-plist.reb %.plist and
  // provisioning profiles. Those codecs have no encoder.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "write %/tmp/rebal-codec.xml {<b/>} write %/tmp/rebal-codec.pom {<b/>} write %/tmp/rebal-codec.plist {<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>Name</key><string>Ada</string></dict></plist>} (reduce [(load %/tmp/rebal-codec.xml) = decode 'xml {<b/>} (load %/tmp/rebal-codec.pom) = decode 'xml {<b/>} (load %/tmp/rebal-codec.plist)/Name = \"Ada\" (type? try [save %/tmp/rebal-codec.xml [1]]) = error! (type? try [save %/tmp/rebal-codec.plist [1]]) = error!]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}
