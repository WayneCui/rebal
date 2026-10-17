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

///|
test "load of an rsa private key file returns a handle" {
  // rsa-test.r3 "RSA private key from OpenSSL format (RSA PRIVATE KEY)".
  let env = @eval.Env::new()
  @eval.write_file(
    "/tmp/rebal-private.key", "-----BEGIN RSA PRIVATE KEY-----\nMIIEoQIBAAKCAQEA8mjwC6ZCwpQCnDXqU7g2tyvMFoWpJV+myfBz9zbhw7rHxUmF\nubMtEwCKQhYccQxbPCcWu/KIg5TOhmcf9RK1xIuUrOUiUdM8uOwRS+e5kitTUgux\n/wjyMNlpK5laIS1hFHiFhCxecN7Won3bsPDMm5Wi3dBMv1+1jK1rlDtJYxDDcJE2\nT59m1UI4AN/Pm7dndr11yCmUdKy6VACf5V7u4OX5uC3fsTEuCV1P2WwLBqtZMYG3\njjzuRTana+s8n2TXk5D9lXoPMc7Tj4/aSw50UUAYhmVpie/8vtVwA7MhOCA4us6q\n3+Mx07vq8EmzbLOGtP9taXQkDF6JR6wY4IEXBwIBJQKCAQAaNNuuO3zWw+SbRBlV\nKKv4IGkXMQtd/IC74qTAx6m0S4s37EXO4vAdut6Dr10FTXGlo1xnWH12Aj/XLb5E\nAgXQDxb970H7AhRnBMOZgNXKnOZpvBM+KnsMMy324CVrXtoQDQeD6R73cgldrL3N\n8ITSjLepRvOKT4k/pAuhUoR5aWK3vZ7+o2xrgG9LSYdaTvSmVQbP0p+Z0vksJjfp\nWAzqOuqMCyviZoUmfHyKcbnsgdZVlYCFdUpXBLLf2lpmLXYGFvW6kSA6gdUUi/kh\nvD2ldZ6bZXm2DgQGMIdt2X2Qd3VwDMhNnKr/4qNZDNlJ4Y9lK3EjvCdl2ot5uFae\nl3FNAoGBAP2AxslebLmhbVLNFikTYVUUr3nhRsVbC/V0Tem0LG4WejVYDdjeZFYk\nZ5h7PM36PVfMpzSsSZMHhl1kCgRtgJYxMndHTPEcUxaAmFnbt/fKzRCY9QO01tk7\n9JGyz3JobiaiL5RCvxGVHzzay8BecuAsPDqTJVUuJuo9IPTYotK1AoGBAPTMMG49\nywJRcN+7YYKE+7tfe3zkhorKwUQHUTECxAlTysrQuLDkmIhA9jddk0VAvQLNM54P\ndmuYxNNxPXQAv72qCiVQbrP4SsoQ6L/3SUJL8wzQBcABF35Jn/mYx+VXYRPMKNnP\nOvJ/rEcdxxki2jgg8VxLwmJwEhTkogLM5WxLAoGAIkHVrIJhuDhouCmNX38o1CVj\n0jMzE8AyDGmpqfXA0JtA8nOu2B4NjxmtInGEweOLv8G1uwKGe6cSKEvKAJktDWCY\nHfTg4k/vjWtS27XobZfyMqzi1vzDFm/ix5S0P+SZQ32zZw/wTnvvdu0ic/EWcVIV\n+hPic0ttCuWqgfPC+eECgYBcoEmtLCNM/DiMAbYxYsAdYmYTlL1JRcyWR/U1I6Qf\nNHY+5zEgVn7ncoatKlNmT9jQoKu/RB74R6Rrrk6amH/m5mS0LEWQNG9TYFgRSM+c\ni3C4vWn1n4xZTEpecSkKq3DXDvqzR34WkSxt75dxS3Up/qCDyaN/MVLzJhPJtU/j\nyQKBgQDhprd4FKjN15L3IJFjPi8UruQBjulZMi4wjJSPPE0LIWI+pbFVk8VghC2z\nQpnl2IrjbB3AV9PUKC6q+SQQDA38nUv0yriDdZgo/J5+PDxRvZXH+9ojQyoAfbol\ntt3RgGsAWb5pU7lnptsViWQppVk2L+QDgvU2AUW9Pw6xJRGAtQ==\n-----END RSA PRIVATE KEY-----\n",
  )
  assert_true(
    @eval.run(
      env, "(reduce [mold load %/tmp/rebal-private.key type? load %/tmp/rebal-private.key]) = reduce [{#(handle! rsa)} handle!]",
    )
    is @value.Logic(true),
  )
}
