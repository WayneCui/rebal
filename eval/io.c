#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int32_t rebal_status = 0;

int32_t rebal_io_status(void) { return rebal_status; }

static char *rebal_to_utf8(const uint16_t *src, int32_t len) {
  if (len < 0) {
    len = 0;
  }
  char *buf = (char *)malloc((size_t)len * 3 + 1);
  if (buf == NULL) {
    return NULL;
  }
  int32_t n = 0;
  for (int32_t i = 0; i < len; i++) {
    uint32_t u = src[i];
    if (u < 0x80) {
      buf[n++] = (char)u;
    } else if (u < 0x800) {
      buf[n++] = (char)(0xC0 | (u >> 6));
      buf[n++] = (char)(0x80 | (u & 0x3F));
    } else {
      buf[n++] = (char)(0xE0 | (u >> 12));
      buf[n++] = (char)(0x80 | ((u >> 6) & 0x3F));
      buf[n++] = (char)(0x80 | (u & 0x3F));
    }
  }
  buf[n] = 0;
  return buf;
}

static int32_t rebal_utf8_units(const unsigned char *data, size_t size) {
  size_t i = 0;
  int32_t units = 0;
  while (i < size) {
    unsigned char c = data[i];
    int need = 1;
    uint32_t cp = c;
    if (c < 0x80) {
      need = 1;
      cp = c;
    } else if ((c & 0xE0) == 0xC0) {
      need = 2;
      cp = c & 0x1F;
    } else if ((c & 0xF0) == 0xE0) {
      need = 3;
      cp = c & 0x0F;
    } else if ((c & 0xF8) == 0xF0) {
      need = 4;
      cp = c & 0x07;
    } else {
      return -1;
    }
    if (i + (size_t)need > size) {
      return -1;
    }
    for (int k = 1; k < need; k++) {
      if ((data[i + (size_t)k] & 0xC0) != 0x80) {
        return -1;
      }
      cp = (cp << 6) | (data[i + (size_t)k] & 0x3F);
    }
    i += (size_t)need;
    if (cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) {
      return -1;
    }
    units += cp > 0xFFFF ? 2 : 1;
  }
  return units;
}

static void rebal_fill_utf16(
  uint16_t *dst,
  const unsigned char *data,
  size_t size
) {
  size_t i = 0;
  int32_t n = 0;
  while (i < size) {
    unsigned char c = data[i];
    int need = 1;
    uint32_t cp = c;
    if (c < 0x80) {
      need = 1;
      cp = c;
    } else if ((c & 0xE0) == 0xC0) {
      need = 2;
      cp = c & 0x1F;
    } else if ((c & 0xF0) == 0xE0) {
      need = 3;
      cp = c & 0x0F;
    } else {
      need = 4;
      cp = c & 0x07;
    }
    for (int k = 1; k < need; k++) {
      cp = (cp << 6) | (data[i + (size_t)k] & 0x3F);
    }
    i += (size_t)need;
    if (cp > 0xFFFF) {
      cp -= 0x10000;
      dst[n++] = (uint16_t)(0xD800 + (cp >> 10));
      dst[n++] = (uint16_t)(0xDC00 + (cp & 0x3FF));
    } else {
      dst[n++] = (uint16_t)cp;
    }
  }
}

moonbit_string_t rebal_read_text(moonbit_string_t path, int32_t path_len) {
  rebal_status = 0;
  char *cpath = rebal_to_utf8(path, path_len);
  if (cpath == NULL) {
    rebal_status = 2;
    return moonbit_make_string(0, 0);
  }
  FILE *file = fopen(cpath, "rb");
  free(cpath);
  if (file == NULL) {
    rebal_status = 1;
    return moonbit_make_string(0, 0);
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    rebal_status = 2;
    return moonbit_make_string(0, 0);
  }
  long size = ftell(file);
  if (size < 0 || fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    rebal_status = 2;
    return moonbit_make_string(0, 0);
  }
  unsigned char *data = (unsigned char *)malloc((size_t)size + 1);
  if (data == NULL) {
    fclose(file);
    rebal_status = 2;
    return moonbit_make_string(0, 0);
  }
  size_t got = fread(data, 1, (size_t)size, file);
  fclose(file);
  size_t start = 0;
  if (got >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) {
    start = 3;
  }
  int32_t units = rebal_utf8_units(data + start, got - start);
  if (units < 0) {
    free(data);
    rebal_status = 2;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, data + start, got - start);
  free(data);
  return text;
}

int32_t rebal_write_text(
  moonbit_string_t path,
  int32_t path_len,
  moonbit_string_t text,
  int32_t text_len
) {
  char *cpath = rebal_to_utf8(path, path_len);
  char *body = rebal_to_utf8(text, text_len);
  if (cpath == NULL || body == NULL) {
    free(cpath);
    free(body);
    return 1;
  }
  FILE *file = fopen(cpath, "wb");
  free(cpath);
  if (file == NULL) {
    free(body);
    return 1;
  }
  size_t len = 0;
  while (body[len] != 0) {
    len++;
  }
  size_t wrote = fwrite(body, 1, len, file);
  free(body);
  int failed = fclose(file) != 0 || wrote != len;
  return failed ? 1 : 0;
}
