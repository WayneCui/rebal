#include <dlfcn.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static int32_t rebal_zlib_status = 0;

static int (*zlib_compress2)(
  unsigned char *,
  unsigned long *,
  const unsigned char *,
  unsigned long,
  int
) = NULL;

static int (*zlib_uncompress)(
  unsigned char *,
  unsigned long *,
  const unsigned char *,
  unsigned long
) = NULL;

static int load_zlib(void) {
  if (zlib_compress2 != NULL && zlib_uncompress != NULL) {
    return 0;
  }
  const char *paths[] = {
    "/usr/lib/libz.dylib",
    "/usr/lib/libz.1.dylib",
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
  zlib_compress2 = dlsym(lib, "compress2");
  zlib_uncompress = dlsym(lib, "uncompress");
  if (zlib_compress2 == NULL || zlib_uncompress == NULL) {
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

int32_t rebal_zlib_code(void) { return rebal_zlib_status; }

moonbit_string_t rebal_zlib_compress(
  moonbit_string_t data,
  int32_t len,
  int32_t level
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
  unsigned long cap = bound_of(len < 0 ? 0 : (unsigned long)len);
  unsigned char *dest = (unsigned char *)malloc(cap);
  if (dest == NULL) {
    free(src);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  unsigned long dest_len = cap;
  int rc = zlib_compress2(
    dest,
    &dest_len,
    src,
    len < 0 ? 0 : (unsigned long)len,
    level
  );
  free(src);
  if (rc != 0 || dest_len > 0x7FFFFFFFUL) {
    free(dest);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = bytes_to_units(dest, (int32_t)dest_len);
  free(dest);
  return text;
}

moonbit_string_t rebal_zlib_decompress(moonbit_string_t data, int32_t len) {
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
  unsigned long cap = src_len * 4 + 64;
  if (cap < 64) {
    cap = 64;
  }
  unsigned char *dest = NULL;
  unsigned long dest_len = 0;
  int rc = -1;
  while (cap <= 64UL * 1024UL * 1024UL) {
    free(dest);
    dest = (unsigned char *)malloc(cap);
    if (dest == NULL) {
      free(src);
      rebal_zlib_status = 1;
      return moonbit_make_string(0, 0);
    }
    dest_len = cap;
    rc = zlib_uncompress(dest, &dest_len, src, src_len);
    if (rc == 0) {
      break;
    }
    if (rc != -5) {
      break;
    }
    if (cap > 32UL * 1024UL * 1024UL) {
      break;
    }
    cap *= 2;
  }
  free(src);
  if (rc != 0 || dest_len > 0x7FFFFFFFUL) {
    free(dest);
    rebal_zlib_status = 1;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = bytes_to_units(dest, (int32_t)dest_len);
  free(dest);
  return text;
}
