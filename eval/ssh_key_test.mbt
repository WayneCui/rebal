///|
test "decode ssh-key turns an ssh-rsa public key into a handle" {
  // crypt-test.r3 SSH-public-key-1. The one-line form is the same blob.
  let env = @eval.Env::new()
  let armored = "---- BEGIN SSH2 PUBLIC KEY ----\nComment: \"1024-bit RSA, converted from OpenSSH by me@example.com\"\nx-command: /home/me/bin/lock-in-guest.sh\nAAAAB3NzaC1yc2EAAAABIwAAAIEA1on8gxCGJJWSRT4uOrR13mUaUk0hRf4RzxSZ1zRb\nYYFw8pfGesIFoEuVth4HKyF8k1y4mRUnYHP1XNMNMJl1JcEArC2asV8sHf6zSPVffozZ\n5TT4SfsUu/iKy9lUcCfXzwre4WWZSXXcPff+EHtWshahu3WzBdnGxm5Xoi89zcE=\n---- END SSH2 PUBLIC KEY ----"
  assert_true(
    @eval.run(
      env,
      "(reduce [mold decode 'ssh-key {" +
      armored +
      "} type? decode 'ssh-key {" +
      armored +
      "}]) = reduce [{#(handle! rsa)} handle!]",
    )
    is @value.Logic(true),
  )
  assert_true(
    @eval.run(
      env, "(mold decode 'ssh-key {ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA1on8gxCGJJWSRT4uOrR13mUaUk0hRf4RzxSZ1zRbYYFw8pfGesIFoEuVth4HKyF8k1y4mRUnYHP1XNMNMJl1JcEArC2asV8sHf6zSPVffozZ5TT4SfsUu/iKy9lUcCfXzwre4WWZSXXcPff+EHtWshahu3WzBdnGxm5Xoi89zcE= me@example.com}) = {#(handle! rsa)}",
    )
    is @value.Logic(true),
  )
  let dss = "---- BEGIN SSH2 PUBLIC KEY ----\nComment: This is my public key for use on \\\nservers which I don't like.\nAAAAB3NzaC1kc3MAAACBAPY8ZOHY2yFSJA6XYC9HRwNHxaehvx5wOJ0rzZdzoSOXxbET\nW6ToHv8D1UJ/z+zHo9Fiko5XybZnDIaBDHtblQ+Yp7StxyltHnXF1YLfKD1G4T6JYrdH\nYI14Om1eg9e4NnCRleaqoZPF3UGfZia6bXrGTQf3gJq2e7Yisk/gF+1VAAAAFQDb8D5c\nvwHWTZDPfX0D2s9Rd7NBvQAAAIEAlN92+Bb7D4KLYk3IwRbXblwXdkPggA4pfdtW9vGf\nJ0/RHd+NjB4eo1D+0dix6tXwYGN7PKS5R/FXPNwxHPapcj9uL1Jn2AWQ2dsknf+i/FAA\nvioUPkmdMc0zuWoSOEsSNhVDtX3WdvVcGcBq9cetzrtOKWOocJmJ80qadxTRHtUAAACB\nAN7CY+KKv1gHpRzFwdQm7HK9bb1LAo2KwaoXnadFgeptNBQeSXG1vO+JsvphVMBJc9HS\nn24VYtYtsMu74qXviYjziVucWKjjKEb11juqnF0GDlB3VVmxHLmxnAz643WK42Z7dLM5\nsY29ouezv4Xz2PuMch5VGPP+CDqzCM4loWgV\n---- END SSH2 PUBLIC KEY ----"
  assert_true(
    @eval.run(env, "(type? try [decode 'ssh-key {" + dss + "}]) = error!")
    is @value.Logic(true),
  )
}
