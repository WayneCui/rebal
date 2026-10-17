#include <dlfcn.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

static int32_t rebal_zlib_status = 0;

static int (*zlib_deflate_init2)(
  z_streamp,
  int,
  int,
  int,
  int,
  int,
  const char *,
  int
) = NULL;
static int (*zlib_deflate)(z_streamp, int) = NULL;
static int (*zlib_deflate_end)(z_streamp) = NULL;
static int (*zlib_inflate_init2)(
  z_streamp,
  int,
  const char *,
  int
) = NULL;
static int (*zlib_inflate)(z_streamp, int) = NULL;
static int (*zlib_inflate_end)(z_streamp) = NULL;

static int load_zlib(void) {
  if (zlib_deflate_init2 != NULL && zlib_inflate_init2 != NULL) {
    return 0;
  }
  const char *paths[] = {
    "/usr/lib/libz.dylib",
    "libz.dylib",
    NULL,
  };
  void *lib = NULL;
  for (int i = 0; paths[i] != NULL && lib == NULL; i++) {
    lib = dlopen(paths[i], RTLD_NOW);
  }
  if (lib == NULL) {
    return 1;
  }
  zlib_deflate_init2 = dlsym(lib, "deflateInit2_");
  zlib_deflate = dlsym(lib, "deflate");
  zlib_deflate_end = dlsym(lib, "deflateEnd");
  zlib_inflate_init2 = dlsym(lib, "inflateInit2_");
  zlib_inflate = dlsym(lib, "inflate");
  zlib_inflate_end = dlsym(lib, "inflateEnd");
  if (
    zlib_deflate_init2 == NULL || zlib_deflate == NULL ||
    zlib_deflate_end == NULL || zlib_inflate_init2 == NULL ||
    zlib_inflate == NULL || zlib_inflate_end == NULL
  ) {
    return 1;
  }
  return 0;
}

static unsigned char *units_to_bytes(const uint16_t *src, int32_t len) {
  if (len < 0) {
    len = 0;
  }
  unsigned char *buf = (unsigned char *)malloc((size_t)len + 1);
  if (buf == NULL) {
    return NULL;
  }
  for (int32_t i = 0; i < len; i++) {
    if (src[i] > 255) {
      free(buf);
      return NULL;
    }
    buf[i] = (unsigned char)src[i];
  }
  return buf;
}

static moonbit_string_t bytes_to_units(const unsigned char *src, int32_t len) {
  moonbit_string_t text = moonbit_make_string(len, 0);
  for (int32_t i = 0; i < len; i++) {
    text[i] = src[i];
  }
  return text;
}

static unsigned long bound_of(unsigned long size) {
  return size + (size >> 12) + (size >> 14) + (size >> 25) + 13;
}

static int grow_out(z_stream *strm, unsigned char **dest, unsigned long *cap) {
  if (*cap > 32UL * 1024UL * 1024UL) {
    return 1;
  }
  unsigned long used = strm->total_out;
  unsigned long next = *cap * 2;
  if (next < 64) {
    next = 64;
  }
  unsigned char *grown = (unsigned char *)realloc(*dest, next);
  if (grown == NULL) {
    return 1;
  }
  *dest = grown;
  *cap = next;
  strm->next_out = grown + used;
  strm->avail_out = (uInt)(next - used);
  return 0;
}

int32_t rebal_zlib_code(void) { return rebal_zlib_status; }

moonbit_string_t rebal_zlib_compress(
  moonbit_string_t data,
  int32_t len,
  int32_t level,
  int32_t window_bits
) {
  rebal_zlib_status = 0;
  if (load_zlib() != 0) {
    rebal_zlib_status = 2;
    return moonbit_make_string(0, 0);
  }
  unsigned char *src = units_to_bytes(data, len);
  if (src == NULL) {
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  unsigned long src_len = len < 0 ? 0 : (unsigned long)len;
  z_stream strm;
  memset(&strm, 0, sizeof(strm));
  int rc = zlib_deflate_init2(
    &strm,
    level,
    Z_DEFLATED,
    window_bits,
    8,
    Z_DEFAULT_STRATEGY,
    ZLIB_VERSION,
    (int)sizeof(z_stream)
  );
  if (rc != Z_OK) {
    free(src);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  unsigned long cap = bound_of(src_len);
  if (cap < 64) {
    cap = 64;
  }
  unsigned char *dest = (unsigned char *)malloc(cap);
  if (dest == NULL) {
    zlib_deflate_end(&strm);
    free(src);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  strm.next_in = src;
  strm.avail_in = (uInt)src_len;
  strm.next_out = dest;
  strm.avail_out = (uInt)cap;
  rc = zlib_deflate(&strm, Z_FINISH);
  while (rc == Z_OK) {
    if (grow_out(&strm, &dest, &cap) != 0) {
      rc = Z_MEM_ERROR;
      break;
    }
    rc = zlib_deflate(&strm, Z_FINISH);
  }
  free(src);
  zlib_deflate_end(&strm);
  if (rc != Z_STREAM_END || strm.total_out > 0x7FFFFFFFUL) {
    free(dest);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = bytes_to_units(dest, (int32_t)strm.total_out);
  free(dest);
  return text;
}

moonbit_string_t rebal_zlib_decompress(
  moonbit_string_t data,
  int32_t len,
  int32_t window_bits
) {
  rebal_zlib_status = 0;
  if (load_zlib() != 0) {
    rebal_zlib_status = 2;
    return moonbit_make_string(0, 0);
  }
  unsigned char *src = units_to_bytes(data, len);
  if (src == NULL) {
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  unsigned long src_len = len < 0 ? 0 : (unsigned long)len;
  z_stream strm;
  memset(&strm, 0, sizeof(strm));
  int rc = zlib_inflate_init2(
    &strm,
    window_bits,
    ZLIB_VERSION,
    (int)sizeof(z_stream)
  );
  if (rc != Z_OK) {
    free(src);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  unsigned long cap = src_len * 4 + 64;
  if (cap < 64) {
    cap = 64;
  }
  unsigned char *dest = (unsigned char *)malloc(cap);
  if (dest == NULL) {
    zlib_inflate_end(&strm);
    free(src);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  strm.next_in = src;
  strm.avail_in = (uInt)src_len;
  strm.next_out = dest;
  strm.avail_out = (uInt)cap;
  rc = zlib_inflate(&strm, Z_NO_FLUSH);
  while (rc == Z_OK) {
    if (grow_out(&strm, &dest, &cap) != 0) {
      rc = Z_MEM_ERROR;
      break;
    }
    rc = zlib_inflate(&strm, Z_NO_FLUSH);
  }
  free(src);
  zlib_inflate_end(&strm);
  if (rc != Z_STREAM_END || strm.total_out > 0x7FFFFFFFUL) {
    free(dest);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = bytes_to_units(dest, (int32_t)strm.total_out);
  free(dest);
  return text;
}
