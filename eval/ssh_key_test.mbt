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

///|
test "load of a pkcs8 private key file returns a handle" {
  // rsa-test.r3 "RSA private key from OpenSSL x509 format (PRIVATE KEY)".
  let env = @eval.Env::new()
  @eval.write_file(
    "/tmp/rebal-pkcs8.key", "-----BEGIN PRIVATE KEY-----\nMIIJRAIBADANBgkqhkiG9w0BAQEFAASCCS4wggkqAgEAAoICAQCmTSzCTtU2/MVz\nZLY99kFPlh9wp4miUO5BEdxM+tbhAAKQ+bn1N3hNgmINu7pe2l6HAPWxa5fDNyAU\nrwiOfH5yIms+99Xq0EER4q1o7yuBhcIhNSY+qVMTjePYIW6vlDLy0NSDA6rBoyo8\nPSi/ruOteRBAHXiIoKzT1Si3r6OrV3ZHQACfp0is/LjcB4FtomszaIfQuU9nBHWe\n3uEOAbF+6DHGUV2/DGULxZmEILS/wB4PUrriWoEyJGfU6OVzjETo0m0QskJ3eeV+\nnJFt4a0TqLRH9b6evYpNb5QbDVYm7bZPunTh5fSGXdfA/vqqylGMUSmVK9/8Zp/K\nGr72HFl/kqIYHHYyJE+aQEls7XlYOgHBchGw4Y9PHHn+EMi8gbnhtLnGOnk05YpJ\n24yrLD6V+iPUuBvmEMHbNX3TlmIgrl77AajGpDGoMqLmvtzmUcJ2WBJY0uE6JnZR\n2Ivl3jO63JCMZJviFs+LB1/wD5od5l6uRAV84ciSgtKjU2PPvkymsfkIg9avSHja\ndVsaYgJU0+2g8z7d//xrR0PwYIVTxRx0RrpiPiPw940LeTOpaelaSWM9/Xr3FID/\nFQLK1Mw/IE4k2/uQbtg72cjgHYRoSOKfPQ18F5E7SuzWtTdvxTdcxBjhDHfsYHlX\nN2qkJsfCQhquvUE1r59zGNiFQzwAoQIDAQABAoICAQCI8orGZIbepl+vfCM7eVwl\nPvobGkyUN1NMkHm7huGHHiv+2TeSwSA3rAQ1TP/X9rnbMSYi+fhbET1A6zb/p3O1\nZ7SrgQpPOToskV++Rx6rpcvM7ujUtzmro7AansV4n3EpVmF6ln16wnQYcUDqQQpL\nI6QHOH22/aH1O9cxFNmSUw8a85DP6MFHe0J8J04lS5g+GHmnn8LMkfaOYvowP6K8\nYFgE+aJansljXVDjZs+SDJJ0ietOVbuI4EQFJ9k0QzHIDOk106Y6n04m6qY0N6EA\nzG/RxoQ4UtvekuEDOgNVQXJdy61PDcBFGmh/DTq9hKiNBZVZu2zTfGtf0pCpOYVU\n3kW0v1zW+gMckRBbPEmVnkWQCt6Xfhmdme/Fk1GyJ8xZGcDcwkxSdn0M0bL1c5Aw\nvKqjWIas0RfyJHOtCkB2EYYPwNE1HVbpWMpW6AWVLElrYUkz4pGYDA8x8kmxo4Ge\nqnqyNk6ShIf2kI3ilBJ3fZPWsr+fko2LSAYbVF+jLx+vDzaWFzHGgFBLZhtsYjOQ\n1xvU7k0HjZ6P0/Pxp8pASqpFkXePJshgnsVoDsJKY84Ui90EzyPiYXIX8FT7zHTw\nG7mHVHz3Xz10cM+fPDDltPq+GJfYUjTcrmpNwoDBnhGx5zQGbXh1eLJzxeBoHJgP\nHk+Bx7h52zS2bt9afZcqMQKCAQEAzwR+BrnxD2tFa9RJuCvxq+TS58VvkgkubQqx\nEot1XYKm7WxoYkhyk03JE/pvnlP43DLuVdmJpLw1aUSMQ3P4+Re/pmzEz4bD8mFC\nJgUWJ7aqtAgW3fGOLpLxxjD2zQTwjKK5h1fhxW2OxNSIHUc0lNovoaM2uZbPwBTr\nYT1vQXsRs1CQmWcCwf0MVvGlo+B60opG378LzQGtQBjnURnMf06zhs825D6GplvN\nbtJPMxIGOOH9CbQQdj67ODfhdbL32n/VZbnU52902aUTVkgxUuK9xWwDnP0AGWUK\nEr5Ij99vQpA4Ym7/PJ73CTYDoucmNwzg5/6qkoid/DA8pqs9FQKCAQEAzaZrfojg\nS/LqLolLu7pswWmn5M4NtTzN/DEVQwELC09nHEbcYWA0Trzr37sRgrRhWs/mTDO3\nYQSypVoXcGO61hG2/GEpvCJcqk2DNfkByUbPfACh4VRHFzjsco3qvXlAmrBjR3CJ\n2Dt/GLDa5SfisQyisPuUzrtquVyF9jSqk62VPyR01WPeb4V/VmK6O0KjYZi5ofNQ\nzclexaXRK1S9jDtkaibF1HXDAUdygw/UnTZbdbVxX25rJiW4yqT94obzCPynXiO8\nS+Ev27lWX3An9nKyJ4c02xMOyKqyOVYwQn2pgkicDveCM+GtrEMkXoRdYVlKhMbA\nIMqH4+v7Cr+QXQKCAQBAcUSN8XoB88GjhG0CYOOVP+ELdyF5E1SZaxeeDz2Uw2QV\nSobf+W95PWCX0IDIh5lTaqNYpCQ93Ly/rTAAm2xoliT5uKg3ddsva2k9Dp5L9IgF\nDPOZWWWKSAHtUTaysZP0I3+fixLj82vbB9HrU0wh/h2PspAJi9HWGG0BUy978cSb\nzjuFFVT9cDlUI1sNvYZeXd8cLYuN4LS+3EG9tEs9YhFuqLiMqo4d4Tv9AIjY/AZl\n1KuBRsVNGdAL+xE7I2AWa27RgNyuwrpcOg/f7w8znxO2Dh690uAiB5rwJL3P05z9\n2olC0wyvIUkDXAYbwtrZji/A6DzO6qpLY/StaWbVAoIBAQC/lGKdvWuetUyeT78i\nwthgEkqbZ63zghKu9xbElesw/SakfAsAF/yCwZLHmWEFr37md7kmkiMqmZLHYbdm\nNzIuDNC4KtgTcLt817r9g9y7ImFWNsyXusiDhL8ZNMZS/utFcD78pYV00HBlkxRI\n2LBhmdDSKX0GXihdSClwJL4n11SrPw4sYN4ubGIlGtI9NKY53GpKyf4jx42neQL0\nZ/ww8H9qOHahp5cj0OiH2i6KysHHVWGpspbVMd0Fw1DVQDyWybAtjgLzeXP5MJ6b\nSEOiXlVDZ7zAve9O114y9ez9dE1+lp/zfXZpWLtPODlgZ9UKRIGcUf9YTPTtSsBS\n0gTtAoIBAQCbfGkosguBoMq/GyWlaT7PJLsl9voS7MamUHeod/0vfwO+rxtN9zJL\n5i93zerhlFVEGXJtkLe88c3VqaKbjWqcLZMO3pQZ+iP967N43P9HkhgWH6fNSFM5\nlSEH2juK6drx9MrjRK78gcGc1Y1ryPpqkqCa/C61bpMH+cfNFBfwxg/iVcYEfg7i\nXnDbEw/xNEq9f5XY9dZJlb9MTlDgB+1z2zakQqVC4GZzRqYpazw6txXdPeyISthb\nQP2QBBpTNkzUWLFzZJ5EMRjGDz+l1rx0WUfaWMbkU7n0hF3NVAmXNS/fhmdszYXW\n16AeXFDJSx8U70+5T6rF9x2ZL1DYXwQd\n-----END PRIVATE KEY-----\n",
  )
  assert_true(
    @eval.run(
      env, "(reduce [mold load %/tmp/rebal-pkcs8.key type? load %/tmp/rebal-pkcs8.key]) = reduce [{#(handle! rsa)} handle!]",
    )
    is @value.Logic(true),
  )
}

///|
test "load of a dh parameter file returns a dhm handle" {
  // crypt-test.r3 "Init public DH params from file".
  let env = @eval.Env::new()
  @eval.write_file(
    "/tmp/rebal-dhparam.key", "-----BEGIN DH PARAMETERS-----\nMIIBCAKCAQEAhR9gLa+RbIUY+u3qZHRwTfw4Q0VoJOv4FK3et9HQNSvZmmUqzcG/\nt3v3TPD3NRsLTh7hrvQcWFR7dsgqLFjqrMvthcRXsLYOxsT9ERL3nMPloEItggRG\n9hk3RzGFYb9nx56RXDJ3Nh+/pYfG3Ab+3gt+V/7Ato+Ws61lHVQmQ1cBUvkdjy4i\nuIm5vr91VVgMc8Bi9PvhsPhjU4f9LQIykiY7+nsJpbgNdlU55Db8/Atc3PnL11z/\nxXjmnj1QBjWymkz5LDEMJYCkMcFGwiToL6+jYjAkG1GpU6Jt4C5Z00E4LERy/jCi\ngeGoH8yNQvldeqw5lTcNpaWWB2+ROqUj0wIBAg==\n-----END DH PARAMETERS-----",
  )
  assert_true(
    @eval.run(
      env, "(reduce [mold load %/tmp/rebal-dhparam.key query load %/tmp/rebal-dhparam.key 'type]) = reduce [{#(handle! dhm)} 'dhm]",
    )
    is @value.Logic(true),
  )
}
