///|
test "mime-type? maps a suffix to its media type" {
  // codec-mime-types.reb. The last listing wins. The key is case-folded.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "(reduce [(mime-type? %a.html) = \"text/html\" (mime-type? %HTML) = \"text/html\" (mime-type? %foo.JPEG) = \"image/jpeg\" (mime-type? %.css) = \"text/css\" (mime-type? %txt) = \"text/plain\" (mime-type? %exe) = \"application/octet-stream\" (mime-type? %deb) = \"application/octet-stream\" (mime-type? %rpm) = \"application/x-redhat-package-manager\" (mime-type? %Z) = \"application/x-compress\" (mime-type? 'html) = \"text/html\" (mime-type? %a.b.c.svgz) = \"image/svg+xml\" (mime-type? next %x.html) = \"text/html\" (mime-type? %dir/file.PNG) = \"image/png\" none? mime-type? none none? mime-type? %nope none? mime-type? %a. none? mime-type? %dir/Z ((try [mime-type? \"html\"])/id) = 'expect-arg ((try [mime-type? \"html\"])/arg1) = \"mime-type?\"]) = reduce [true true true true true true true true true true true true true true true true true true true]",
    )
    is @value.Logic(true),
  )
}
