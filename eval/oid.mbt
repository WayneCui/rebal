///|
/// `codecs/der/decode-oid` from codec-der.reb.
/// A recognized arc list becomes a word. Anything else becomes the dotted
/// numeric string. A name is kept even when extra bytes follow it: the Rebol
/// rule assigns the name before `end` can fail.
fn decode_oid(env : Env, value : @value.Cell) -> @value.Cell raise EvalError {
  let bytes = payload_bytes(value, "decode")
  if bytes.length() == 0 {
    @value.None
  } else {
    match oid_name(bytes) {
      Some(spelling) => oid_word(env, spelling)
      None => text_series(form_oid(bytes))
    }
  }
}

///|
fn oid_word(env : Env, spelling : String) -> @value.Cell {
  let sym = env.symbols.intern(spelling)
  @value.Sym(@value.Word, @value.Lexeme::make(sym, spelling))
}

///|
fn form_oid(bytes : Array[Int]) -> String {
  let first = bytes[0]
  let mut out = (first / 40).to_string() + "." + (first % 40).to_string()
  let mut value = 0L
  let mut index = 1
  while index < bytes.length() {
    let byte = bytes[index].to_int64()
    value = (value << 7) + (byte & 127L)
    if (byte & 128L) == 0L {
      out = out + "." + value.to_string()
      value = 0L
    }
    index = index + 1
  }
  out
}

///|
fn oid_prefix(bytes : Array[Int], pat : Array[Int]) -> Bool {
  if pat.length() > bytes.length() {
    false
  } else {
    let mut index = 0
    let mut same = true
    while same && index < pat.length() {
      if bytes[index] != pat[index] {
        same = false
      }
      index = index + 1
    }
    same
  }
}

///|
fn oid_selector(bytes : Array[Int], prefix : Array[Int]) -> Int? {
  if oid_prefix(bytes, prefix) && bytes.length() > prefix.length() {
    Some(bytes[prefix.length()])
  } else {
    None
  }
}

///|
fn oid_name(bytes : Array[Int]) -> String? {
  match oiw_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match pkix_access_info_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match pkix_access_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match x962_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match pkcs_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match cipher_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match secg_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match x520_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match x509_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match key_purpose_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  match enterprise_oid(bytes) {
    Some(name) => return Some(name)
    None => ()
  }
  attribute_oid(bytes)
}

///|
fn oiw_oid(bytes : Array[Int]) -> String? {
  match oid_selector(bytes, [0x2B, 0x0E, 0x03, 0x02]) {
    Some(0x01) => Some("rsa")
    Some(0x02) => Some("md4WithRSA")
    Some(0x03) => Some("md5WithRSA")
    Some(0x04) => Some("md4WithRSAEncryption")
    Some(0x06) => Some("desECB")
    Some(0x07) => Some("desCBC")
    Some(0x0B) => Some("rsaSignature")
    Some(0x0C) => Some("dsaSignature")
    Some(0x0D) => Some("dsaWithSHA")
    Some(0x1A) => Some("sha1")
    Some(0x1D) => Some("sha1WithRSAEncryption")
    _ => None
  }
}

///|
fn pkix_access_info_oid(bytes : Array[Int]) -> String? {
  if oid_prefix(bytes, [0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x01, 0x01]) {
    Some("authorityInfoAccess")
  } else {
    None
  }
}

///|
fn pkix_access_oid(bytes : Array[Int]) -> String? {
  match oid_selector(bytes, [0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x30]) {
    Some(0x01) => Some("ocsp")
    Some(0x02) => Some("caIssuers")
    Some(0x03) => Some("timeStamping")
    Some(0x05) => Some("caRepository")
    _ => None
  }
}

///|
fn x962_oid(bytes : Array[Int]) -> String? {
  let root = [0x2A, 0x86, 0x48, 0xCE, 0x3D]
  if oid_prefix(bytes, root + [0x02, 0x01]) {
    Some("ecPublicKey")
  } else if oid_prefix(bytes, root + [0x03, 0x01, 0x07]) {
    Some("secp256r1")
  } else if oid_prefix(bytes, root + [0x03, 0x01, 0x01]) {
    Some("secp192r1")
  } else if oid_prefix(bytes, root + [0x04, 0x03, 0x01]) {
    Some("ecdsa-with-SHA224")
  } else if oid_prefix(bytes, root + [0x04, 0x03, 0x02]) {
    Some("ecdsa-with-SHA256")
  } else if oid_prefix(bytes, root + [0x04, 0x03, 0x03]) {
    Some("ecdsa-with-SHA384")
  } else if oid_prefix(bytes, root + [0x04, 0x03, 0x04]) {
    Some("ecdsa-with-SHA512")
  } else {
    None
  }
}

///|
fn pkcs_oid(bytes : Array[Int]) -> String? {
  let root = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01]
  if !oid_prefix(bytes, root) || bytes.length() < 9 {
    None
  } else {
    let branch = bytes[7]
    if branch == 0x01 {
      pkcs1_name(bytes[8])
    } else if branch == 0x07 {
      pkcs7_name(bytes[8])
    } else if branch == 0x09 {
      pkcs9_name(bytes[8])
    } else if branch == 0x0C {
      pkcs12_name(bytes)
    } else {
      None
    }
  }
}

///|
fn pkcs1_name(byte : Int) -> String? {
  if byte == 0x01 {
    Some("rsaEncryption")
  } else if byte == 0x02 {
    Some("md2WithRSAEncryption")
  } else if byte == 0x03 {
    Some("md4withRSAEncryption")
  } else if byte == 0x04 {
    Some("md5withRSAEncryption")
  } else if byte == 0x05 {
    Some("sha1WithRSAEncrption")
  } else if byte == 0x0B {
    Some("sha256WithRSAEncryption")
  } else if byte == 0x0C {
    Some("sha384WithRSAEncryption")
  } else if byte == 0x0D {
    Some("sha512WithRSAEncryption")
  } else if byte == 0x0E {
    Some("sha224WithRSAEncryption")
  } else {
    None
  }
}

///|
fn pkcs7_name(byte : Int) -> String? {
  if byte == 0x01 {
    Some("data")
  } else if byte == 0x02 {
    Some("signedData")
  } else if byte == 0x03 {
    Some("envelopedData")
  } else if byte == 0x04 {
    Some("signedAndEnvelopedData")
  } else if byte == 0x05 {
    Some("digestedData")
  } else if byte == 0x06 {
    Some("encryptedData")
  } else {
    None
  }
}

///|
fn pkcs9_name(byte : Int) -> String? {
  if byte == 0x01 {
    Some("emailAddress")
  } else if byte == 0x02 {
    Some("unstructuredName")
  } else if byte == 0x03 {
    Some("contentType")
  } else if byte == 0x04 {
    Some("messageDigest")
  } else if byte == 0x05 {
    Some("signingTime")
  } else if byte == 0x06 {
    Some("counterSignature")
  } else if byte == 0x07 {
    Some("challengePassword")
  } else if byte == 0x08 {
    Some("unstructuredAddress")
  } else if byte == 0x0E {
    Some("extensionRequest")
  } else {
    None
  }
}

///|
fn pkcs12_name(bytes : Array[Int]) -> String? {
  if bytes.length() > 9 && bytes[8] == 0x01 && bytes[9] == 0x06 {
    Some("pbeWithSHAAnd40BitRC2-CBC")
  } else if bytes.length() > 9 && bytes[8] == 0x01 && bytes[9] == 0x03 {
    Some("pbeWithSHAAnd3-KeyTripleDES-CBC")
  } else if bytes.length() > 10 &&
    bytes[8] == 0x0A &&
    bytes[9] == 0x01 &&
    bytes[10] == 0x02 {
    Some("pkcs-12-pkcs-8ShroudedKeyBag")
  } else {
    None
  }
}

///|
fn cipher_oid(bytes : Array[Int]) -> String? {
  match oid_selector(bytes, [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x03]) {
    Some(0x02) => Some("rc2CBC")
    Some(0x03) => Some("rc2ECB")
    Some(0x04) => Some("rc4")
    Some(0x05) => Some("rc4WithMAC")
    Some(0x06) => Some("DESx")
    Some(0x07) => Some("tripleDES-CBC")
    Some(0x08) => Some("rc5CBC")
    Some(0x09) => Some("rc5ECB")
    _ => None
  }
}

///|
fn secg_oid(bytes : Array[Int]) -> String? {
  match oid_selector(bytes, [0x2B, 0x81, 0x04, 0x00]) {
    Some(0x01) => Some("secp192r1")
    Some(0x02) => Some("sect163k1")
    Some(0x03) => Some("sect163r1")
    Some(0x04) => Some("sect239k1")
    Some(0x05) => Some("sect283k1")
    Some(0x06) => Some("sect283r1")
    Some(0x07) => Some("secp160k1")
    Some(0x08) => Some("secp160r1")
    Some(0x09) => Some("secp160r2")
    Some(0x0A) => Some("secp192k1")
    Some(0x0F) => Some("secp256k1")
    Some(0x10) => Some("sect233k1")
    Some(0x11) => Some("sect233r1")
    Some(0x21) => Some("secp224r1")
    Some(0x22) => Some("secp384r1")
    Some(0x23) => Some("secp521r1")
    _ => None
  }
}

///|
fn x520_oid(bytes : Array[Int]) -> String? {
  match oid_selector(bytes, [0x55, 0x04]) {
    Some(0x03) => Some("commonName")
    Some(0x06) => Some("countryName")
    Some(0x07) => Some("localityName")
    Some(0x08) => Some("stateOrProvinceName")
    Some(0x09) => Some("streetAddress")
    Some(0x0A) => Some("organizationName")
    Some(0x0B) => Some("organizationalUnitName")
    Some(0x0C) => Some("title")
    Some(0x0D) => Some("description")
    Some(0x0E) => Some("searchGuide")
    Some(0x0F) => Some("businessCategory")
    Some(0x10) => Some("postalAddress")
    Some(0x11) => Some("spostalCode")
    Some(0x12) => Some("postOfficeBox")
    Some(0x13) => Some("physicalDeliveryOfficeName")
    Some(0x14) => Some("telephoneNumber")
    _ => None
  }
}

///|
fn x509_oid(bytes : Array[Int]) -> String? {
  match oid_selector(bytes, [0x55, 0x1D]) {
    Some(0x01) => Some("authorityKeyIdentifier")
    Some(0x02) => Some("keyAttributes")
    Some(0x03) => Some("certificatePolicies")
    Some(0x04) => Some("keyUsageRestriction")
    Some(0x0E) => Some("subjectKeyIdentifier")
    Some(0x0F) => Some("keyUsage")
    Some(0x11) => Some("subjectAltName")
    Some(0x12) => Some("issuerAlternativeName")
    Some(0x13) => Some("basicConstraints")
    Some(0x1E) => Some("nameConstraints")
    Some(0x1F) => Some("CRLDistributionPoints")
    Some(0x20) => Some("certificatePolicies")
    Some(0x21) => Some("policyMappings")
    Some(0x23) => Some("authorityKeyIdentifier")
    Some(0x24) => Some("policyConstraints")
    Some(0x25) => Some("extendedKeyUsage")
    Some(0x2E) => Some("freshestCRL")
    _ => None
  }
}

///|
fn key_purpose_oid(bytes : Array[Int]) -> String? {
  match oid_selector(bytes, [0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03]) {
    Some(0x01) => Some("serverAuth")
    Some(0x02) => Some("clientAuth")
    Some(0x03) => Some("codeSigning")
    Some(0x04) => Some("emailProtection")
    Some(0x08) => Some("timeStamping")
    Some(0x09) => Some("OCSPSigning")
    _ => None
  }
}

///|
fn enterprise_oid(bytes : Array[Int]) -> String? {
  let root = [0x2B, 0x06, 0x01, 0x04, 0x01]
  if oid_prefix(bytes, root + [0x82, 0x37, 0x02, 0x01, 0x15]) {
    Some("individualCodeSigning")
  } else if oid_prefix(bytes, root + [0xD6, 0x79, 0x02, 0x04, 0x02]) {
    Some("X509Extension")
  } else {
    None
  }
}

///|
fn attribute_oid(bytes : Array[Int]) -> String? {
  if oid_prefix(bytes, [
      0x09, 0x92, 0x26, 0x89, 0x93, 0xF2, 0x2C, 0x64, 0x01, 0x01,
    ]) {
    Some("uid")
  } else {
    None
  }
}
