///|
test "load, save, and do of a script file" {
  let env = @eval.Env::new()
  @eval.write_file("/tmp/rebal-script.r3", "Rebol [title: {t}]\n1 + 2\n")
  assert_true(@eval.run(env, "do %/tmp/rebal-script.r3") is @value.Integer(3L))
  assert_true(
    @eval.run(env, "(load %/tmp/rebal-script.r3) = [1 + 2]")
    is @value.Logic(true),
  )
  @eval.write_file("/tmp/rebal-one.r3", "Rebol [title: {t}]\n3\n")
  assert_true(
    @eval.run(env, "(load %/tmp/rebal-one.r3) = 3") is @value.Logic(true),
  )
  @eval.write_file("/tmp/rebal-header.r3", "REBOL [a: 1]\n1 2\n")
  assert_true(
    @eval.run(env, "(load %/tmp/rebal-header.r3) = [1 2]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(load {Rebol [title: {t}] 1 2}) = [1 2]")
    is @value.Logic(true),
  )
  assert_true(@eval.run(env, "(load {4}) = 4") is @value.Logic(true))
  assert_true(
    @eval.run(env, "(load {Rebol 1}) = [Rebol 1]") is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "do {Rebol [title: {t}] 2 + 3}") is @value.Integer(5L),
  )
  assert_true(
    @eval.run(
      env, "save %/tmp/rebal-save.r3 [1 + 2] (load %/tmp/rebal-save.r3) = [1 + 2]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "save %/tmp/rebal-num.r3 1 + 2 do %/tmp/rebal-num.r3")
    is @value.Integer(3L),
  )
  assert_true(
    @eval.run(env, "(type? save %/tmp/rebal-save.r3 3) = file!")
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(env, "(load %/tmp/rebal-save.r3) = 3") is @value.Logic(true),
  )
  let missing = try {
    @eval.run(env, "load %/tmp/rebal-no-such-file.r3") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(missing)
  let bad = try {
    @eval.run(env, "save 1 2") |> ignore
    false
  } catch {
    error => error.id() == "cannot"
  }
  assert_true(bad)
}

///|
test "save into a binary round-trips through load" {
  // codecs-test.r3 "SAVE to binary!". none returns the script bytes.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(load save #{} \"1\") = \"1\" (load save #{} #{CAFE}) = #{CAFE} (load save #{} [1 2]) = [1 2] (save none \"1\") = #{2231220A} (save #{} #{CAFE}) = #{237B434146457D0A}]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "save/compress writes zlib, a header, or a base-64 script" {
  // codecs-test.r3 "SAVE/compress". false is the payload alone.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(save/compress none [print \"Hello World!\"] false) = #{789C2B28CACC2B5150F248CDC9C95708CF2FCA495154E20200526B06D9} (load decompress save/compress none [print \"Hello World!\"] false 'zlib) = [print \"Hello World!\"] (save/compress none [print \"Hello World!\"] true) = #{5245424F4C205B0A202020206F7074696F6E733A205B636F6D70726573735D0A5D0A789C2B28CACC2B5150F248CDC9C95708CF2FCA495154E20200526B06D9} (save/compress none [print \"Hello World!\"] 'script) = #{5245424F4C205B0A202020206F7074696F6E733A205B636F6D70726573735D0A5D0A3634237B654A77724B4D724D4B314651386B6A4E79636C58434D3876796B6C52564F494341464A7242746B3D7D}]) = reduce [true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "a header compresses the body when options contain compress" {
  // mezz-save.reb. The checksum is of the script before zlib.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "s: save/header/compress none [print \"Hello REBOL!\"] [checksum: true] true t: save/header/compress none 1 [options: [foo]] true u: save/header none 1 [options: [compress]] (reduce [(load s) = [print \"Hello REBOL!\"] ((pick load/header s 1)/options) = [compress] ((pick load/header s 1)/checksum) = #{4DC8C9EE0414047082FF60E6A26A908DC7873FCD} (save/header/compress none 1 [checksum: true] false) = save/header none 1 [checksum: true] (load t) = 1 ((pick load/header t 1)/options) = [foo compress] (load u) = 1 (load save/header/compress none [1] [checksum: true] 'script) = 1]) = reduce [true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "save/header stores a SHA1 checksum and load checks it" {
  // load-test.r3 "Script checksum verification".
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "s: save/header none [print \"Hello REBOL!\"] [checksum: true] (reduce [s = #{5245424F4C205B0A20202020636865636B73756D3A20237B344443384339454530343134303437303832464636304536413236413930384443373837334643447D0A5D0A7072696E74202248656C6C6F205245424F4C21220A} (load s) = [print \"Hello REBOL!\"] ((pick load/header s 1)/checksum) = #{4DC8C9EE0414047082FF60E6A26A908DC7873FCD} (save/header none 1 [title: \"t\" checksum: true]) = #{5245424F4C205B0A202020207469746C653A202274220A20202020636865636B73756D3A20237B453546413434463242333143314642353533423630323145373336304430374435443931464635457D0A5D0A310A} (save/header none 1 []) = #{5245424F4C205B5D0A310A}]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
  match
    @eval.run(
      env, "try [load #{5245424F4C205B0A20202020636865636B73756D3A20237B344443384339454530343134303437303832464636304536413236413930384443373837334643447D0A5D0A7072696E74202258656C6C6F205245424F4C21220A}]",
    ) {
    @value.Error(err) => assert_true(err.id == "bad-checksum")
    _ => assert_true(false)
  }
  match @eval.run(env, "try [load {REBOL [checksum: true] 1}]") {
    @value.Error(err) => assert_true(err.id == "bad-checksum")
    _ => assert_true(false)
  }
}

///|
test "save/length counts the bytes that follow a custom header" {
  // mezz-save.reb. Compression and base 64 are included in the count.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "s: save/length/header none [print \"Hello REBOL!\"] [title: \"t\"] c: save/header/length none [1] [checksum: true] z: save/length/compress none [1] true (reduce [s = #{5245424F4C205B0A202020207469746C653A202274220A202020206C656E6774683A2032310A5D0A7072696E74202248656C6C6F205245424F4C21220A} (load s) = [print \"Hello REBOL!\"] ((pick load/header s 1)/title) = \"t\" ((pick load/header s 1)/length) = 21 c = #{5245424F4C205B0A20202020636865636B73756D3A20237B453546413434463242333143314642353533423630323145373336304430374435443931464635457D0A202020206C656E6774683A20320A5D0A310A} (save/header/length none [1] [length: 5]) = #{5245424F4C205B0A202020206C656E6774683A20320A5D0A310A} (save/header/compress/length none [1] [options: [compress]] false) = #{5245424F4C205B0A202020206F7074696F6E733A205B5D0A202020206C656E6774683A20320A5D0A310A} (load z) = 1 ((pick load/header z 1)/options) = [compress] ((pick load/header z 1)/length) = length? compress \"1^/\" 'zlib]) = reduce [true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "save/length records how many script bytes follow the header" {
  // load-test.r3 "Save/length". The body is `print "Hello REBOL!"` plus a newline.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "s: save/length none [print \"Hello REBOL!\"] (reduce [s = #{5245424F4C205B0A202020206C656E6774683A2032310A5D0A7072696E74202248656C6C6F205245424F4C21220A} (load s) = [print \"Hello REBOL!\"] ((pick load/header s 1)/length) = 21]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "a header length keeps only that many body bytes" {
  // load-test.r3 "Length-specified script embedding".
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(load {rebol [length: 14] print \"hello\" other stuff}) = [print \"hello\"] (load {rebol [length: 2] 1 2}) = 1 (load {rebol [length: 0] print \"hello\"}) = [] (load {rebol [length: 100] 1 2}) = [1 2]]) = reduce [true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "load maps over a block of sources" {
  // load-test.r3 "Load of a block!".
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "b: load [\"print 'hello\" \"print 'there\"] (reduce [(type? b) = block! (pick b 1) = [print 'hello] (pick b 2) = [print 'there] (type? pick pick b 1 2) = lit-word! (load [\"1\"]) = [1] (load [\"1\" \"2 3\"]) = [1 [2 3]] (load/all [\"1\"]) = [[1]]]) = reduce [true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "load skips a UTF-8 BOM on a binary" {
  // load-test.r3 "load UTF8 string from binary with BOM".
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(load #{223322}) = \"3\" (load #{EFBBBF223322}) = \"3\" (load #{EFBBBF5265626F6C205B7469746C653A207B743D7D5D20310A}) = 1]) = reduce [true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "a script header turns yes, no, and none into values" {
  // load-test.r3 issue-655. construct, not evaluation.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "o: pick load/header {rebol [a: true b: yes c: no d: false e: none f: foo g: on h: off] print 'hello} 1 (reduce [(type? o/a) = logic! o/a o/b not o/c not o/d none? o/e (type? o/f) = word! o/g not o/h]) = reduce [true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "an html suffix loads as markup and cannot be saved as a script" {
  // base-defs.reb. Saving one of these suffixes without /header is invalid-arg.
  @eval.write_file("/tmp/rebal-m.html", "<a>b</c>")
  @eval.write_file("/tmp/rebal-m.htm", "<!--hi-->x")
  @eval.write_file("/tmp/rebal-m.HTML", "<a>b</c>")
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(load %/tmp/rebal-m.html) = [<a> \"b\" </c>] (load %/tmp/rebal-m.htm) = [<!--hi--> \"x\"] (load %/tmp/rebal-m.HTML) = [<a> \"b\" </c>] (load/header %/tmp/rebal-m.html) = [<a> \"b\" </c>] ((try [save %/tmp/rebal-m.html \"x\"])/id) = 'invalid-arg]) = reduce [true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "save writes text for a .txt or .cgi file and a script otherwise" {
  // mezz-save.reb. A text suffix encodes the value. /header still writes a script.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "t: save %/tmp/rebal-suf.txt [1 2] c: save %/tmp/rebal-suf.cgi [%a %b] (reduce [t = %/tmp/rebal-suf.txt (load t) = \"1 2\" (load/as t none) = [1 2] (load save %/tmp/rebal-suf.bin [1 2]) = [1 2] (load c) = \"%a %b\" (load save %/tmp/rebal-suf.TXT [1 2]) = \"1 2\" (load save %/tmp/rebal-suf.txt \"hi\") = {\"hi\"} (load save %/tmp/rebal-suf.txt #{616263}) = \"abc\" (load save/compress %/tmp/rebal-suf.txt [print \"Hi\"] true) = {print \"Hi\"} (load save/length %/tmp/rebal-suf.txt [1 2]) = \"1 2\"]) = reduce [true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "load/as text decodes bytes, and none or unbound loads code" {
  // sys-load.reb. text folds CR and LF. none ignores a codec suffix.
  @eval.write_file("/tmp/rebal-as.txt", "hello\r\n")
  @eval.write_file("/tmp/rebal-as.r3", "1\n")
  @eval.write_file("/tmp/rebal-as.pem", "1\n")
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(load/as \"1 2\" 'text) = \"1 2\" (load/as #{312032} 'text) = \"1 2\" (load/as #{} 'text) = \"\" (load/as #{C3A9} 'text) = \"é\" (load/as #{EFBBBF610D0A62} 'text) = \"a^/b\" (load/as #{610D62} 'text) = \"a^/b\" (load/as #{610A0D62} 'text) = \"a^/b\" (load/header/as \"1\" 'text) = \"1\" (load/all/as \"1 2\" 'text) = \"1 2\" (load/as [\"31\" #{32}] 'text) = [\"31\" \"2\"] (load/as %/tmp/rebal-as.txt 'text) = \"hello^/\" (load %/tmp/rebal-as.r3) = 1 (load/as %/tmp/rebal-as.r3 'text) = \"1^/\" (load/as %/tmp/rebal-as.r3 none) = 1 (load %/tmp/rebal-as.pem) = none (load/as %/tmp/rebal-as.pem none) = 1 (load/as \"1 2\" 'unbound) = [1 2] (load/as \"1\" none) = 1 ((pick load/header/as {rebol [title: \"t\"] 1} none 1)/title) = \"t\" (pick load/header/as {rebol [title: \"t\"] 1} none 2) = 1 ((try [load/as \"1\" 1])/id) = 'expect-arg (type? try [load/as \"1\" 'nope]) = error!]) = reduce [true true true true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "load/as text reads UTF-16 and UTF-32 when a BOM is present" {
  // s-unicode.c What_UTF. No BOM stays UTF-8. A broken unit is refused.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(load/as #{FFFE61006200} 'text) = \"ab\" (load/as #{FEFF00610062} 'text) = \"ab\" (load/as #{FFFE000061000000} 'text) = \"a\" (load/as #{0000FEFF00000061} 'text) = \"a\" (load/as #{FFFE} 'text) = \"\" (load/as #{FFFE61000D000A006200} 'text) = \"a^/b\" (load/as #{FFFE61000D006200} 'text) = \"a^/b\" (load/as #{FFFE3DD802DC} 'text) = \"🐂\" (load/as #{61006200} 'text) = \"a^@b^@\" (type? try [load/as #{FFFE00D8} 'text]) = error! (type? try [load/as #{FFFE000000001100} 'text]) = error!]) = reduce [true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "load/as markup splits tags from the text between them" {
  // load-test.r3 "load/as markup". An unclosed tag drops the `<`.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(load/as \"<a>b</c>\" 'markup) = [<a> \"b\" </c>] (load/as #{3C613E623C2F633E} 'markup) = [<a> \"b\" </c>] (load/as \"a<b\" 'markup) = [\"a\" \"b\"] (load/as \"<!--hi-->x\" 'markup) = [<!--hi--> \"x\"] (load/as \"1<2>3\" 'markup) = [\"1<2>3\"] (load/header/as \"<a>b</c>\" 'markup) = [<a> \"b\" </c>] (type? try [load/as \"1\" 'nope]) = error!]) = reduce [true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "load/all keeps a series position and does not read the header" {
  // load-test.r3 "Load/all". mold/all writes #(string! "123" 2).
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "v: mold/all next \"123\" b: load/all v (reduce [v = {#(string! \"123\" 2)} (type? b) = block! (pick b 1) = \"23\" (head pick b 1) = \"123\" (mold/all next #{010203}) = {#(binary! #{010203} 2)} (pick load/all mold/all next #{010203} 1) = #{0203} (mold/all next [a b c]) = {#(block! [a b c] 2)} (pick load/all mold/all next [a b c] 1) = [b c] (load/all \"1\") = [1] (load/all {Rebol [title: \"t\"] 1}) = [Rebol [title: \"t\"] 1] (load/header/all {1}) = reduce [none 1]]) = reduce [true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}

///|
test "load reads a compressed script and can keep its header" {
  // codecs-test.r3 "SAVE/compress". /header puts the object first.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "b: save/compress none [print \"Hello World!\"] true s: save/compress none [print \"Hello World!\"] 'script (reduce [(load b) = [print \"Hello World!\"] (load s) = [print \"Hello World!\"] (length? load/header b) = 3 (type? pick load/header b 1) = object! ((pick load/header b 1)/options) = [compress] ((pick load/header b 1)/title) = \"Untitled\" ((pick load/header b 1)/version) = 0.0.0 ((pick load/header s 1)/options) = [compress] (load/header {1}) = reduce [none 1] ((pick load/header {Rebol [title: \"t\"] 2} 1)/title) = \"t\" (pick load/header {Rebol [title: \"t\"] 2} 2) = 2]) = reduce [true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
