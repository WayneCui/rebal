///|
test "mime-field unfolds a header and decodes utf-8 words" {
  // codecs-test.r3 "decode/encode mime-field". ISO-8859-2 here is ASCII.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(decode 'mime-field {Subject: Hello Mail}) = {Subject: Hello Mail} (decode 'mime-field {Labels: =?UTF-8?Q?Doru=C4=8Den=C3=A9,Nep=C5=99e=C4=8Dten=C3=A9?=}) = {Labels: Doručené,Nepřečtené} (decode 'mime-field {=?UTF-8?B?d2ViIHBybyDFvmFyb8WhaWNl?=}) = {web pro žarošice} (decode 'mime-field {Subject: =?UTF-8?Q?Fwd=3A_objedn=C3=A1vka?=}) = {Subject: Fwd: objednávka} (decode 'mime-field {(=?UTF-8?Q?a?= =?UTF-8?Q?b?=)}) = {(ab)} (decode 'mime-field {(=?UTF-8?Q?a?= b)}) = {(a b)} (decode 'mime-field {(=?UTF-8?Q?a_b?=)}) = {(a b)} (decode 'mime-field \"xxxxx^M^/ yyyy\") = {xxxxx yyyy} (decode 'mime-field \"xxxxx^M^/ =?utf-8?Q?yyyy?=\") = {xxxxxyyyy} (decode 'mime-field \"a^M^/   b\") = {a b} (decode 'mime-field {=?ISO-8859-1?Q?Patrik_F=E4ltstr=F6m?=}) = {Patrik Fältström} (decode 'mime-field {=?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?==?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=}) = {If you can read this you understand the example.}]) = reduce [true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "mime-field encode keeps a plain header and wraps the rest" {
  // codecs-test.r3 encode path. Chunks are 17 code points, base64 from Rebol.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(encode 'mime-field {Subject: Hello Mail}) = {Subject: Hello Mail} (encode 'mime-field {web pro žarošice}) = {=?UTF-8?B?d2ViIHBybyDFvmFyb8WhaWNl?=} (encode 'mime-field {Hello, Mail}) = {=?UTF-8?B?SGVsbG8sIE1haWw=?=} (encode 'mime-field {Labels: Doručené,Nepřečtené}) = \"Labels: =?UTF-8?B?RG9ydcSNZW7DqSxOZXDFmWXEjXRl?=^M^/ =?UTF-8?B?bsOp?=\" (decode 'mime-field encode 'mime-field {Labels: Doručené,Nepřečtené}) = {Labels: Doručené,Nepřečtené}]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}
