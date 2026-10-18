///|
test "dh init agrees on a shared secret" {
  // n-crypt.c dh-init / dh/public / dh/secret. The prime is 512 bits.
  let env = @eval.Env::new()
  assert_true(
    @eval.run(
      env, "g: #{00A9876A74FDC5E8BD0535A4787875C02384694ACFE3697524F5101DD3AF0AFCB7FAECAC19B79B8933307CEFBB18860A2059275C1E0B9FAC266338EA954362EEB1} p: #{00D8DAE761EEEF79A0365038644789B65117AC3CDFB738DABF700D569783FEF795AA5FE54B9D6114471245391D4DD6287A7EB66A52546044E151738B4A0DF21F93} a: dh-init g p b: dh-init g p pa: dh/public a pb: dh/public b sa: dh/secret a pb sb: dh/secret b pa (reduce [mold a query a 'type pa <> pb (sa = sb) (length? sa) > 0 none? dh-init #{02} #{05} none? dh/secret a #{01} release a (type? try [dh/public a])]) = reduce [{#(handle! dhm)} 'dhm true true true true true true error!]",
    )
    is @value.Logic(true),
  )
}
