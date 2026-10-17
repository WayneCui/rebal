///|
test "load of an unencrypted putty key returns a handle" {
  // crypt-test.r3 "Init RSA key from PPK file" and "Init public RSA key from SSH2 PPK file".
  let env = @eval.Env::new()
  @eval.write_file(
    "/tmp/rebal-public.ppk", "---- BEGIN SSH2 PUBLIC KEY ----\nComment: \"rsa-key-rebol-test\"\nAAAAB3NzaC1yc2EAAAABJQAAAQEA8mjwC6ZCwpQCnDXqU7g2tyvMFoWpJV+myfBz\n9zbhw7rHxUmFubMtEwCKQhYccQxbPCcWu/KIg5TOhmcf9RK1xIuUrOUiUdM8uOwR\nS+e5kitTUgux/wjyMNlpK5laIS1hFHiFhCxecN7Won3bsPDMm5Wi3dBMv1+1jK1r\nlDtJYxDDcJE2T59m1UI4AN/Pm7dndr11yCmUdKy6VACf5V7u4OX5uC3fsTEuCV1P\n2WwLBqtZMYG3jjzuRTana+s8n2TXk5D9lXoPMc7Tj4/aSw50UUAYhmVpie/8vtVw\nA7MhOCA4us6q3+Mx07vq8EmzbLOGtP9taXQkDF6JR6wY4IEXBw==\n---- END SSH2 PUBLIC KEY ----\n",
  )
  @eval.write_file(
    "/tmp/rebal-private.ppk", "PuTTY-User-Key-File-2: ssh-rsa\nEncryption: none\nComment: rsa-key-rebol-test\nPublic-Lines: 6\nAAAAB3NzaC1yc2EAAAABJQAAAQEA8mjwC6ZCwpQCnDXqU7g2tyvMFoWpJV+myfBz\n9zbhw7rHxUmFubMtEwCKQhYccQxbPCcWu/KIg5TOhmcf9RK1xIuUrOUiUdM8uOwR\nS+e5kitTUgux/wjyMNlpK5laIS1hFHiFhCxecN7Won3bsPDMm5Wi3dBMv1+1jK1r\nlDtJYxDDcJE2T59m1UI4AN/Pm7dndr11yCmUdKy6VACf5V7u4OX5uC3fsTEuCV1P\n2WwLBqtZMYG3jjzuRTana+s8n2TXk5D9lXoPMc7Tj4/aSw50UUAYhmVpie/8vtVw\nA7MhOCA4us6q3+Mx07vq8EmzbLOGtP9taXQkDF6JR6wY4IEXBw==\nPrivate-Lines: 14\nAAABABo02647fNbD5JtEGVUoq/ggaRcxC138gLvipMDHqbRLizfsRc7i8B263oOv\nXQVNcaWjXGdYfXYCP9ctvkQCBdAPFv3vQfsCFGcEw5mA1cqc5mm8Ez4qewwzLfbg\nJWte2hANB4PpHvdyCV2svc3whNKMt6lG84pPiT+kC6FShHlpYre9nv6jbGuAb0tJ\nh1pO9KZVBs/Sn5nS+SwmN+lYDOo66owLK+JmhSZ8fIpxueyB1lWVgIV1SlcEst/a\nWmYtdgYW9bqRIDqB1RSL+SG8PaV1nptlebYOBAYwh23ZfZB3dXAMyE2cqv/io1kM\n2Unhj2UrcSO8J2Xai3m4Vp6XcU0AAACBAP2AxslebLmhbVLNFikTYVUUr3nhRsVb\nC/V0Tem0LG4WejVYDdjeZFYkZ5h7PM36PVfMpzSsSZMHhl1kCgRtgJYxMndHTPEc\nUxaAmFnbt/fKzRCY9QO01tk79JGyz3JobiaiL5RCvxGVHzzay8BecuAsPDqTJVUu\nJuo9IPTYotK1AAAAgQD0zDBuPcsCUXDfu2GChPu7X3t85IaKysFEB1ExAsQJU8rK\n0Liw5JiIQPY3XZNFQL0CzTOeD3ZrmMTTcT10AL+9qgolUG6z+ErKEOi/90lCS/MM\n0AXAARd+SZ/5mMflV2ETzCjZzzryf6xHHccZIto4IPFcS8JicBIU5KICzOVsSwAA\nAIEA4aa3eBSozdeS9yCRYz4vFK7kAY7pWTIuMIyUjzxNCyFiPqWxVZPFYIQts0KZ\n5diK42wdwFfT1CguqvkkEAwN/J1L9Mq4g3WYKPyefjw8Ub2Vx/vaI0MqAH26Jbbd\n0YBrAFm+aVO5Z6bbFYlkKaVZNi/kA4L1NgFFvT8OsSURgLU=\nPrivate-MAC: ae8cac65d4d96599886f6efaaa703176960f3983\n",
  )
  assert_true(
    @eval.run(
      env, "(reduce [mold load %/tmp/rebal-public.ppk mold load %/tmp/rebal-private.ppk query load %/tmp/rebal-private.ppk 'type]) = reduce [{#(handle! rsa)} {#(handle! rsa)} 'rsa]",
    )
    is @value.Logic(true),
  )
}
