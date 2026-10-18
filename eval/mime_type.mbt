///|
/// Suffix to media type, as in codec-mime-types.reb. The last assignment
/// wins when one suffix is listed twice. The lookup key is the text after
/// the last dot, or the whole name when there is no dot.
fn mime_type(value : @value.Cell) -> @value.Cell raise EvalError {
  let key = match value {
    @value.None => return @value.Cell::None
    @value.Sym(datatype, lexeme) if datatype == @value.Word =>
      mime_tail(lexeme.spelling())
    @value.Seq(series, index) if series.datatype() == @value.File =>
      mime_tail(text_from(series, index))
    _ => raise EvalError::Caused("expect-arg", "mime-type?")
  }
  match mime_lookup(key) {
    Some(name) => text_series(name)
    None => @value.Cell::None
  }
}

///|
fn mime_tail(text : String) -> String {
  let mut dot = -1
  let mut index = 0
  for char in text {
    if char == '.' {
      dot = index
    }
    index = index + 1
  }
  let tail = if dot >= 0 {
    text[dot + 1:text.length()].to_owned()
  } else {
    text
  }
  tail.to_lower()
}

///|
fn mime_lookup(key : String) -> String? {
  match key {
    "html" => Some("text/html")
    "htm" => Some("text/html")
    "shtml" => Some("text/html")
    "css" => Some("text/css")
    "xml" => Some("text/xml")
    "mml" => Some("text/mathml")
    "txt" => Some("text/plain")
    "jad" => Some("text/vnd.sun.j2me.app-descriptor")
    "wml" => Some("text/vnd.wap.wml")
    "htc" => Some("text/x-component")
    "gif" => Some("image/gif")
    "jpeg" => Some("image/jpeg")
    "jpg" => Some("image/jpeg")
    "jxl" => Some("image/jxl")
    "jp2" => Some("image/jp2")
    "jpx" => Some("image/jpx")
    "avif" => Some("image/avif")
    "dds" => Some("image/dds")
    "heic" => Some("image/heic")
    "dwg" => Some("image/vnd.dwg")
    "png" => Some("image/png")
    "apng" => Some("image/apng")
    "qoi" => Some("image/qoi")
    "svg" => Some("image/svg+xml")
    "svgz" => Some("image/svg+xml")
    "tif" => Some("image/tiff")
    "tiff" => Some("image/tiff")
    "wbmp" => Some("image/vnd.wap.wbmp")
    "psd" => Some("image/vnd.adobe.photoshop")
    "jxd" => Some("image/vnd.ms-photo")
    "webp" => Some("image/webp")
    "ico" => Some("image/x-icon")
    "jng" => Some("image/x-jng")
    "bmp" => Some("image/x-ms-bmp")
    "xcf" => Some("image/x-xcf")
    "cr2" => Some("image/x-canon-cr2")
    "woff" => Some("font/woff")
    "woff2" => Some("font/woff2")
    "gz" => Some("application/gzip")
    "js" => Some("application/javascript")
    "atom" => Some("application/atom+xml")
    "rss" => Some("application/rss+xml")
    "jar" => Some("application/java-archive")
    "war" => Some("application/java-archive")
    "ear" => Some("application/java-archive")
    "json" => Some("application/json")
    "hqx" => Some("application/mac-binhex40")
    "doc" => Some("application/msword")
    "dcm" => Some("application/dicom")
    "pdf" => Some("application/pdf")
    "ps" => Some("application/postscript")
    "eps" => Some("application/postscript")
    "ai" => Some("application/postscript")
    "rtf" => Some("application/rtf")
    "m3u8" => Some("application/vnd.apple.mpegurl")
    "kml" => Some("application/vnd.google-earth.kml+xml")
    "kmz" => Some("application/vnd.google-earth.kmz")
    "cab" => Some("application/vnd.ms-cab-compressed")
    "xls" => Some("application/vnd.ms-excel")
    "eot" => Some("application/vnd.ms-fontobject")
    "ppt" => Some("application/vnd.ms-powerpoint")
    "odg" => Some("application/vnd.oasis.opendocument.graphics")
    "odp" => Some("application/vnd.oasis.opendocument.presentation")
    "ods" => Some("application/vnd.oasis.opendocument.spreadsheet")
    "odt" => Some("application/vnd.oasis.opendocument.text")
    "pptx" =>
      Some(
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      )
    "xlsx" =>
      Some("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    "docx" =>
      Some(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      )
    "wmlc" => Some("application/vnd.wap.wmlc")
    "wasm" => Some("application/wasm")
    "zst" => Some("application/zstd")
    "zstd" => Some("application/zstd")
    "7z" => Some("application/x-7z-compressed")
    "br" => Some("application/x-brotli")
    "bz2" => Some("application/x-bzip2")
    "cco" => Some("application/x-cocoa")
    "deb" => Some("application/octet-stream")
    "elf" => Some("application/x-executable")
    "crx" => Some("application/x-google-chrome-extension")
    "jardiff" => Some("application/x-java-archive-diff")
    "jnlp" => Some("application/x-java-jnlp-file")
    "lz4" => Some("application/x-lz4")
    "lz" => Some("application/x-lzip")
    "lzop" => Some("application/x-lzop")
    "run" => Some("application/x-makeself")
    "exe" => Some("application/octet-stream")
    "nes" => Some("application/x-nintendo-nes-rom")
    "pl" => Some("application/x-perl")
    "pm" => Some("application/x-perl")
    "prc" => Some("application/x-pilot")
    "pdb" => Some("application/x-pilot")
    "rar" => Some("application/x-rar-compressed")
    "rpm" => Some("application/x-redhat-package-manager")
    "tar" => Some("application/x-tar")
    "sea" => Some("application/x-sea")
    "swf" => Some("application/x-shockwave-flash")
    "sqlite" => Some("application/x-sqlite3")
    "sit" => Some("application/x-stuffit")
    "tcl" => Some("application/x-tcl")
    "tk" => Some("application/x-tcl")
    "ar" => Some("application/x-unix-archive")
    "der" => Some("application/x-x509-ca-cert")
    "pem" => Some("application/x-x509-ca-cert")
    "crt" => Some("application/x-x509-ca-cert")
    "xpi" => Some("application/x-xpinstall")
    "xz" => Some("application/x-xz")
    "z" => Some("application/x-compress")
    "xhtml" => Some("application/xhtml+xml")
    "xspf" => Some("application/xspf+xml")
    "zip" => Some("application/zip")
    "bin" => Some("application/octet-stream")
    "dll" => Some("application/octet-stream")
    "dmg" => Some("application/octet-stream")
    "iso" => Some("application/octet-stream")
    "img" => Some("application/octet-stream")
    "msi" => Some("application/octet-stream")
    "msp" => Some("application/octet-stream")
    "msm" => Some("application/octet-stream")
    "epub" => Some("application/epub+zip")
    "mid" => Some("audio/midi")
    "midi" => Some("audio/midi")
    "kar" => Some("audio/midi")
    "mp3" => Some("audio/mpeg")
    "ogg" => Some("audio/ogg")
    "m4a" => Some("audio/x-m4a")
    "ra" => Some("audio/x-realaudio")
    "wav" => Some("audio/x-wav")
    "3gpp" => Some("video/3gpp")
    "3gp" => Some("video/3gpp")
    "ts" => Some("video/mp2t")
    "mp4" => Some("video/mp4")
    "mpeg" => Some("video/mpeg")
    "mpg" => Some("video/mpeg")
    "mov" => Some("video/quicktime")
    "webm" => Some("video/webm")
    "flv" => Some("video/x-flv")
    "m4v" => Some("video/x-m4v")
    "mng" => Some("video/x-mng")
    "asx" => Some("video/x-ms-asf")
    "asf" => Some("video/x-ms-asf")
    "wmv" => Some("video/x-ms-wmv")
    "avi" => Some("video/x-msvideo")
    "eml" => Some("message/rfc822")
    _ => None
  }
}
