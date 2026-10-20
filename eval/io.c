#include <arpa/inet.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <moonbit.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdint.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static int32_t rebal_status = 0;

int32_t rebal_random_byte(void) {
  static FILE *src;
  if (src == NULL) {
    src = fopen("/dev/urandom", "rb");
    if (src == NULL) {
      return 0;
    }
  }
  int byte = fgetc(src);
  if (byte < 0) {
    fclose(src);
    src = NULL;
    return 0;
  }
  return byte;
}

int32_t rebal_io_status(void) { return rebal_status; }

char *rebal_to_utf8(const uint16_t *src, int32_t len) {
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

int32_t rebal_utf8_units(const unsigned char *data, size_t size) {
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

void rebal_fill_utf16(
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

moonbit_string_t rebal_read_bytes(moonbit_string_t path, int32_t path_len) {
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
  moonbit_string_t text = moonbit_make_string((int32_t)got, 0);
  for (size_t i = 0; i < got; i++) {
    text[i] = data[i];
  }
  free(data);
  return text;
}

int32_t rebal_write_bytes(
  moonbit_string_t path,
  int32_t path_len,
  moonbit_string_t data,
  int32_t data_len
) {
  char *cpath = rebal_to_utf8(path, path_len);
  if (cpath == NULL) {
    return 1;
  }
  if (data_len < 0) {
    data_len = 0;
  }
  unsigned char *body = (unsigned char *)malloc((size_t)data_len + 1);
  if (body == NULL) {
    free(cpath);
    return 1;
  }
  for (int32_t i = 0; i < data_len; i++) {
    if (data[i] > 255) {
      free(cpath);
      free(body);
      return 1;
    }
    body[i] = (unsigned char)data[i];
  }
  FILE *file = fopen(cpath, "wb");
  free(cpath);
  if (file == NULL) {
    free(body);
    return 1;
  }
  size_t wrote = fwrite(body, 1, (size_t)data_len, file);
  free(body);
  int failed = fclose(file) != 0 || wrote != (size_t)data_len;
  return failed ? 1 : 0;
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

// `write/append` shares the writing path with "wb" openers above, only the
// open mode differs, so the tail of the file is kept.
int32_t rebal_append_text(
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
  FILE *file = fopen(cpath, "ab");
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

int32_t rebal_append_bytes(
  moonbit_string_t path,
  int32_t path_len,
  moonbit_string_t data,
  int32_t data_len
) {
  char *cpath = rebal_to_utf8(path, path_len);
  if (cpath == NULL) {
    return 1;
  }
  if (data_len < 0) {
    data_len = 0;
  }
  unsigned char *body = (unsigned char *)malloc((size_t)data_len + 1);
  if (body == NULL) {
    free(cpath);
    return 1;
  }
  for (int32_t i = 0; i < data_len; i++) {
    if (data[i] > 255) {
      free(cpath);
      free(body);
      return 1;
    }
    body[i] = (unsigned char)data[i];
  }
  FILE *file = fopen(cpath, "ab");
  free(cpath);
  if (file == NULL) {
    free(body);
    return 1;
  }
  size_t wrote = fwrite(body, 1, (size_t)data_len, file);
  free(body);
  int failed = fclose(file) != 0 || wrote != (size_t)data_len;
  return failed ? 1 : 0;
}

static int32_t rebal_line_code = 0;

int32_t rebal_line_status(void) { return rebal_line_code; }

moonbit_string_t rebal_read_line(void) {
  rebal_line_code = 0;
  char buf[4096];
  if (fgets(buf, 4096, stdin) == NULL) {
    rebal_line_code = 1;
    return moonbit_make_string(0, 0);
  }
  size_t got = 0;
  while (buf[got] != 0) {
    got++;
  }
  if (got > 0 && buf[got - 1] == '\n') {
    got--;
  }
  if (got > 0 && buf[got - 1] == '\r') {
    got--;
  }
  int32_t units = rebal_utf8_units((unsigned char *)buf, got);
  if (units < 0) {
    rebal_line_code = 2;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, (unsigned char *)buf, got);
  return text;
}

int32_t rebal_write_stdout(moonbit_string_t text, int32_t text_len) {
  char *body = rebal_to_utf8(text, text_len);
  if (body == NULL) {
    return 1;
  }
  if (fputs(body, stdout) < 0) {
    free(body);
    return 1;
  }
  free(body);
  return fflush(stdout) == 0 ? 0 : 1;
}

static void rebal_append(char **out, size_t *len, size_t *cap, const char *text) {
  size_t add = strlen(text);
  while (*len + add + 1 > *cap) {
    *cap = *cap == 0 ? 64 : *cap * 2;
    char *grown = (char *)realloc(*out, *cap);
    if (grown == NULL) {
      return;
    }
    *out = grown;
  }
  memcpy(*out + *len, text, add);
  *len += add;
  (*out)[*len] = 0;
}

moonbit_string_t rebal_list_dir(moonbit_string_t path, int32_t path_len) {
  rebal_status = 0;
  char *cpath = rebal_to_utf8(path, path_len);
  if (cpath == NULL) {
    rebal_status = 2;
    return moonbit_make_string(0, 0);
  }
  DIR *dir = opendir(cpath);
  if (dir == NULL) {
    free(cpath);
    rebal_status = 1;
    return moonbit_make_string(0, 0);
  }
  size_t cap = 64;
  size_t len = 0;
  char *out = (char *)malloc(cap);
  if (out == NULL) {
    closedir(dir);
    free(cpath);
    rebal_status = 2;
    return moonbit_make_string(0, 0);
  }
  out[0] = 0;
  struct dirent *entry;
  while ((entry = readdir(dir)) != NULL) {
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    size_t path_n = strlen(cpath);
    size_t name_n = strlen(entry->d_name);
    int slash = path_n > 0 && cpath[path_n - 1] == '/';
    char *full = (char *)malloc(path_n + name_n + 2);
    if (full == NULL) {
      continue;
    }
    memcpy(full, cpath, path_n);
    if (!slash) {
      full[path_n] = '/';
      memcpy(full + path_n + 1, entry->d_name, name_n + 1);
    } else {
      memcpy(full + path_n, entry->d_name, name_n + 1);
    }
    struct stat info;
    int is_dir = stat(full, &info) == 0 && S_ISDIR(info.st_mode);
    free(full);
    if (len > 0) {
      rebal_append(&out, &len, &cap, "\n");
    }
    rebal_append(&out, &len, &cap, entry->d_name);
    if (is_dir) {
      rebal_append(&out, &len, &cap, "/");
    }
  }
  closedir(dir);
  free(cpath);
  int32_t units = rebal_utf8_units((unsigned char *)out, len);
  if (units < 0) {
    free(out);
    rebal_status = 2;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, (unsigned char *)out, len);
  free(out);
  return text;
}

int32_t rebal_make_dir(moonbit_string_t path, int32_t path_len) {
  char *cpath = rebal_to_utf8(path, path_len);
  if (cpath == NULL) {
    return 1;
  }
  int failed = mkdir(cpath, 0755) != 0 && errno != EEXIST;
  free(cpath);
  return failed ? 1 : 0;
}

int32_t rebal_remove_dir(moonbit_string_t path, int32_t path_len) {
  char *cpath = rebal_to_utf8(path, path_len);
  if (cpath == NULL) {
    return 1;
  }
  int failed = rmdir(cpath) != 0;
  free(cpath);
  return failed ? 1 : 0;
}

static int32_t rebal_cwd_status = 0;

int32_t rebal_cwd_code(void) { return rebal_cwd_status; }

moonbit_string_t rebal_current_dir(void) {
  rebal_cwd_status = 0;
  char *buf = getcwd(NULL, 0);
  if (buf == NULL) {
    rebal_cwd_status = 1;
    return moonbit_make_string(0, 0);
  }
  size_t len = strlen(buf);
  int add = (len == 0 || buf[len - 1] != '/') ? 1 : 0;
  unsigned char *full = (unsigned char *)malloc(len + (size_t)add);
  if (full == NULL) {
    free(buf);
    rebal_cwd_status = 1;
    return moonbit_make_string(0, 0);
  }
  memcpy(full, buf, len);
  if (add) {
    full[len] = '/';
  }
  free(buf);
  int32_t units = rebal_utf8_units(full, len + (size_t)add);
  if (units < 0) {
    free(full);
    rebal_cwd_status = 2;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, full, len + (size_t)add);
  free(full);
  return text;
}

int32_t rebal_change_dir(moonbit_string_t path, int32_t path_len) {
  char *cpath = rebal_to_utf8(path, path_len);
  if (cpath == NULL) {
    return 1;
  }
  int failed = chdir(cpath) != 0;
  free(cpath);
  return failed ? 1 : 0;
}

static int32_t rebal_env_status = 0;

int32_t rebal_env_found(void) { return rebal_env_status; }

moonbit_string_t rebal_get_env(moonbit_string_t name, int32_t name_len) {
  rebal_env_status = 0;
  char *cname = rebal_to_utf8(name, name_len);
  if (cname == NULL) {
    rebal_env_status = 2;
    return moonbit_make_string(0, 0);
  }
  const char *value = getenv(cname);
  free(cname);
  if (value == NULL) {
    rebal_env_status = 1;
    return moonbit_make_string(0, 0);
  }
  size_t len = strlen(value);
  int32_t units = rebal_utf8_units((const unsigned char *)value, len);
  if (units < 0) {
    rebal_env_status = 2;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, (const unsigned char *)value, len);
  return text;
}

int32_t rebal_set_env(
  moonbit_string_t name,
  int32_t name_len,
  moonbit_string_t value,
  int32_t value_len
) {
  char *cname = rebal_to_utf8(name, name_len);
  if (cname == NULL) {
    return 1;
  }
  char *cvalue = rebal_to_utf8(value, value_len);
  if (cvalue == NULL) {
    free(cname);
    return 1;
  }
  int failed = setenv(cname, cvalue, 1) != 0;
  free(cname);
  free(cvalue);
  return failed ? 1 : 0;
}

static int32_t rebal_call_result = 0;
static char *rebal_err_captured = NULL;
static size_t rebal_err_len = 0;

int32_t rebal_call_code(void) { return rebal_call_result; }

static void rebal_clear_error(void) {
  free(rebal_err_captured);
  rebal_err_captured = NULL;
  rebal_err_len = 0;
}

moonbit_string_t rebal_call_error(void) {
  if (rebal_err_captured == NULL || rebal_err_len == 0) {
    rebal_clear_error();
    return moonbit_make_string(0, 0);
  }
  int32_t units =
    rebal_utf8_units((unsigned char *)rebal_err_captured, rebal_err_len);
  if (units < 0) {
    rebal_clear_error();
    rebal_call_result = -1;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, (unsigned char *)rebal_err_captured, rebal_err_len);
  rebal_clear_error();
  return text;
}

static void rebal_keep_error(char *buf, size_t len) {
  rebal_clear_error();
  rebal_err_captured = buf;
  rebal_err_len = len;
}

static void rebal_add_bytes(
  char **out,
  size_t *len,
  size_t *cap,
  const char *text,
  size_t add
);

static void rebal_drain_fd(int *fd, char **buf, size_t *len, size_t *cap) {
  char tmp[1024];
  ssize_t got = read(*fd, tmp, sizeof tmp);
  if (got > 0) {
    rebal_add_bytes(buf, len, cap, tmp, (size_t)got);
    return;
  }
  close(*fd);
  *fd = -1;
}

static void rebal_add_bytes(
  char **out,
  size_t *len,
  size_t *cap,
  const char *text,
  size_t add
) {
  while (*len + add + 1 > *cap) {
    *cap = *cap == 0 ? 64 : *cap * 2;
    char *grown = (char *)realloc(*out, *cap);
    if (grown == NULL) {
      return;
    }
    *out = grown;
  }
  memcpy(*out + *len, text, add);
  *len += add;
  (*out)[*len] = 0;
}

moonbit_string_t rebal_spawn(
  moonbit_string_t packed,
  int32_t packed_len,
  int32_t flags,
  moonbit_string_t input,
  int32_t input_len
) {
  rebal_call_result = -1;
  rebal_clear_error();
  int wait_flag = (flags & 1) != 0;
  int shell = (flags & 2) != 0;
  int capture = (flags & 4) != 0;
  int capture_err = (flags & 8) != 0;
  if (capture || capture_err) {
    wait_flag = 1;
  }
  char *body = rebal_to_utf8(packed, packed_len);
  char *in_body = NULL;
  if (input_len > 0) {
    in_body = rebal_to_utf8(input, input_len);
  }
  if (body == NULL || (input_len > 0 && in_body == NULL)) {
    free(body);
    free(in_body);
    return moonbit_make_string(0, 0);
  }
  char *argv_store[64];
  int argc = 0;
  if (shell) {
    argv_store[0] = "/bin/sh";
    argv_store[1] = "-c";
    argv_store[2] = body;
    argv_store[3] = NULL;
    argc = 3;
  } else {
    argv_store[argc++] = body;
    size_t n = strlen(body);
    for (size_t i = 0; i < n && argc < 63; i++) {
      if (body[i] == 1) {
        body[i] = 0;
        argv_store[argc++] = body + i + 1;
      }
    }
    argv_store[argc] = NULL;
  }
  int in_pipe[2] = { -1, -1 };
  int out_pipe[2] = { -1, -1 };
  int err_pipe[2] = { -1, -1 };
  if (in_body != NULL && pipe(in_pipe) != 0) {
    free(body);
    free(in_body);
    return moonbit_make_string(0, 0);
  }
  if (capture && pipe(out_pipe) != 0) {
    if (in_pipe[0] >= 0) {
      close(in_pipe[0]);
      close(in_pipe[1]);
    }
    free(body);
    free(in_body);
    return moonbit_make_string(0, 0);
  }
  if (capture_err && pipe(err_pipe) != 0) {
    if (in_pipe[0] >= 0) {
      close(in_pipe[0]);
      close(in_pipe[1]);
    }
    if (out_pipe[0] >= 0) {
      close(out_pipe[0]);
      close(out_pipe[1]);
    }
    free(body);
    free(in_body);
    return moonbit_make_string(0, 0);
  }
  pid_t pid = fork();
  if (pid < 0) {
    if (in_pipe[0] >= 0) {
      close(in_pipe[0]);
      close(in_pipe[1]);
    }
    if (out_pipe[0] >= 0) {
      close(out_pipe[0]);
      close(out_pipe[1]);
    }
    if (err_pipe[0] >= 0) {
      close(err_pipe[0]);
      close(err_pipe[1]);
    }
    free(body);
    free(in_body);
    return moonbit_make_string(0, 0);
  }
  if (pid == 0) {
    if (in_pipe[0] >= 0) {
      dup2(in_pipe[0], 0);
      close(in_pipe[0]);
      close(in_pipe[1]);
    }
    if (out_pipe[1] >= 0) {
      dup2(out_pipe[1], 1);
      close(out_pipe[0]);
      close(out_pipe[1]);
    }
    if (err_pipe[1] >= 0) {
      dup2(err_pipe[1], 2);
      close(err_pipe[0]);
      close(err_pipe[1]);
    }
    execvp(argv_store[0], argv_store);
    _exit(127);
  }
  free(body);
  if (in_pipe[0] >= 0) {
    close(in_pipe[0]);
    size_t left = strlen(in_body);
    char *cursor = in_body;
    while (left > 0) {
      ssize_t wrote = write(in_pipe[1], cursor, left);
      if (wrote < 0) {
        break;
      }
      cursor += wrote;
      left -= (size_t)wrote;
    }
    close(in_pipe[1]);
  }
  free(in_body);
  char *captured = NULL;
  size_t captured_len = 0;
  size_t captured_cap = 0;
  char *err_buf = NULL;
  size_t err_len = 0;
  size_t err_cap = 0;
  int out_fd = -1;
  int err_fd = -1;
  if (out_pipe[0] >= 0) {
    close(out_pipe[1]);
    out_fd = out_pipe[0];
  }
  if (err_pipe[0] >= 0) {
    close(err_pipe[1]);
    err_fd = err_pipe[0];
  }
  while (out_fd >= 0 || err_fd >= 0) {
    struct pollfd fds[2];
    int count = 0;
    int out_at = -1;
    int err_at = -1;
    if (out_fd >= 0) {
      fds[count].fd = out_fd;
      fds[count].events = POLLIN;
      out_at = count;
      count += 1;
    }
    if (err_fd >= 0) {
      fds[count].fd = err_fd;
      fds[count].events = POLLIN;
      err_at = count;
      count += 1;
    }
    int ready = poll(fds, (nfds_t)count, -1);
    if (ready < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    if (out_at >= 0 &&
        (fds[out_at].revents & (POLLIN | POLLHUP | POLLERR)) != 0) {
      rebal_drain_fd(&out_fd, &captured, &captured_len, &captured_cap);
    }
    if (err_at >= 0 &&
        (fds[err_at].revents & (POLLIN | POLLHUP | POLLERR)) != 0) {
      rebal_drain_fd(&err_fd, &err_buf, &err_len, &err_cap);
    }
  }
  rebal_keep_error(err_buf, err_len);
  if (wait_flag) {
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
      rebal_call_result = -1;
    } else if (WIFEXITED(status)) {
      rebal_call_result = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
      rebal_call_result = 128 + WTERMSIG(status);
    } else {
      rebal_call_result = -1;
    }
  } else {
    rebal_call_result = (int32_t)pid;
  }
  if (captured == NULL) {
    return moonbit_make_string(0, 0);
  }
  int32_t units = rebal_utf8_units((unsigned char *)captured, captured_len);
  if (units < 0) {
    free(captured);
    rebal_call_result = -1;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, (unsigned char *)captured, captured_len);
  free(captured);
  return text;
}

static int32_t rebal_year = 0;
static int32_t rebal_month = 0;
static int32_t rebal_day = 0;
static int32_t rebal_zone = 0;
static int32_t rebal_weekday = 0;
static int32_t rebal_yearday = 0;
static double rebal_seconds = 0.0;

void rebal_read_clock(int32_t utc, int32_t precise) {
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  struct tm parts;
  if (utc) {
    gmtime_r(&ts.tv_sec, &parts);
    rebal_zone = 0;
  } else {
    localtime_r(&ts.tv_sec, &parts);
    rebal_zone = (int32_t)(parts.tm_gmtoff / 60);
  }
  rebal_year = parts.tm_year + 1900;
  rebal_month = parts.tm_mon + 1;
  rebal_day = parts.tm_mday;
  rebal_seconds =
    parts.tm_hour * 3600.0 + parts.tm_min * 60.0 + parts.tm_sec +
    (precise ? ts.tv_nsec / 1000000000.0 : 0.0);
  rebal_weekday = (parts.tm_wday + 6) % 7 + 1;
  rebal_yearday = parts.tm_yday + 1;
}

int64_t rebal_now_ms(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0;
  }
  return (int64_t)ts.tv_sec * 1000LL + (int64_t)ts.tv_nsec / 1000000LL;
}

int32_t rebal_sleep(double seconds) {
  if (seconds < 0.0) {
    return 1;
  }
  struct timespec left;
  left.tv_sec = (time_t)seconds;
  double fraction = seconds - (double)left.tv_sec;
  left.tv_nsec = (long)(fraction * 1000000000.0);
  if (left.tv_nsec < 0) {
    left.tv_nsec = 0;
  }
  if (left.tv_nsec > 999999999L) {
    left.tv_nsec = 999999999L;
  }
  while (nanosleep(&left, &left) != 0) {
    if (errno != EINTR) {
      return 1;
    }
  }
  return 0;
}

int32_t rebal_browse(
  moonbit_string_t program,
  int32_t program_len,
  moonbit_string_t target,
  int32_t target_len
) {
  if (program_len <= 0 || target_len <= 0) {
    return 1;
  }
  char *cmd = rebal_to_utf8(program, program_len);
  char *arg = rebal_to_utf8(target, target_len);
  if (cmd == NULL || arg == NULL) {
    free(cmd);
    free(arg);
    return 1;
  }
  pid_t child = fork();
  if (child < 0) {
    free(cmd);
    free(arg);
    return 1;
  }
  if (child == 0) {
    char *argv[3];
    argv[0] = cmd;
    argv[1] = arg;
    argv[2] = NULL;
    execvp(argv[0], argv);
    _exit(127);
  }
  free(cmd);
  free(arg);
  int status = 0;
  if (waitpid(child, &status, 0) < 0) {
    return 1;
  }
  if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
    return 0;
  }
  return 1;
}

int32_t rebal_clock_year(void) { return rebal_year; }
int32_t rebal_clock_month(void) { return rebal_month; }
int32_t rebal_clock_day(void) { return rebal_day; }
int32_t rebal_clock_zone(void) { return rebal_zone; }
int32_t rebal_clock_weekday(void) { return rebal_weekday; }
int32_t rebal_clock_yearday(void) { return rebal_yearday; }
double rebal_clock_seconds(void) { return rebal_seconds; }

static int32_t rebal_tcp_status = 0;

int32_t rebal_tcp_code(void) { return rebal_tcp_status; }

static int rebal_tcp_socket(void) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return -1;
  }
  int yes = 1;
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
  return fd;
}

int32_t rebal_tcp_connect(moonbit_string_t host, int32_t host_len, int32_t port) {
  rebal_tcp_status = 1;
  char *name = rebal_to_utf8(host, host_len);
  if (name == NULL || port < 1 || port > 65535) {
    free(name);
    return -1;
  }
  int fd = rebal_tcp_socket();
  if (fd < 0) {
    free(name);
    return -1;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  if (inet_pton(AF_INET, name, &addr.sin_addr) != 1 ||
      connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    free(name);
    close(fd);
    return -1;
  }
  free(name);
  rebal_tcp_status = 0;
  return fd;
}

int32_t rebal_tcp_send(int32_t fd, moonbit_string_t text, int32_t text_len) {
  rebal_tcp_status = 1;
  char *body = rebal_to_utf8(text, text_len);
  if (body == NULL || fd < 0) {
    free(body);
    return 1;
  }
  size_t len = strlen(body);
  size_t sent = 0;
  while (sent < len) {
    ssize_t n = send(fd, body + sent, len - sent, 0);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      free(body);
      return 1;
    }
    sent += (size_t)n;
  }
  free(body);
  rebal_tcp_status = 0;
  return 0;
}

moonbit_string_t rebal_tcp_recv(int32_t fd) {
  rebal_tcp_status = 1;
  size_t len = 0;
  size_t cap = 64;
  char *buf = malloc(cap);
  if (buf == NULL || fd < 0) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  for (;;) {
    if (len == cap) {
      cap *= 2;
      char *grown = realloc(buf, cap);
      if (grown == NULL) {
        free(buf);
        return moonbit_make_string(0, 0);
      }
      buf = grown;
    }
    ssize_t n = recv(fd, buf + len, cap - len, 0);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      free(buf);
      return moonbit_make_string(0, 0);
    }
    if (n == 0) {
      break;
    }
    len += (size_t)n;
  }
  int32_t units = rebal_utf8_units((unsigned char *)buf, len);
  if (units < 0) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, (unsigned char *)buf, len);
  free(buf);
  rebal_tcp_status = 0;
  return text;
}

int32_t rebal_tcp_close(int32_t fd) {
  if (fd < 0) {
    return 0;
  }
  return close(fd) == 0 ? 0 : 1;
}

static void *rebal_echo_main(void *arg) {
  int listen_fd = (int)(intptr_t)arg;
  struct sockaddr_in peer;
  socklen_t peer_len = sizeof(peer);
  int conn = accept(listen_fd, (struct sockaddr *)&peer, &peer_len);
  close(listen_fd);
  if (conn < 0) {
    return NULL;
  }
  char buf[1024];
  size_t got = 0;
  while (got < sizeof(buf)) {
    ssize_t n = recv(conn, buf + got, 1, 0);
    if (n <= 0) {
      break;
    }
    got += 1;
    if (buf[got - 1] == '\n') {
      break;
    }
  }
  size_t sent = 0;
  while (sent < got) {
    ssize_t n = send(conn, buf + sent, got - sent, 0);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    sent += (size_t)n;
  }
  close(conn);
  return NULL;
}

int32_t rebal_tcp_echo(void) {
  int fd = rebal_tcp_socket();
  if (fd < 0) {
    return -1;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = 0;
  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0 ||
      listen(fd, 1) != 0) {
    close(fd);
    return -1;
  }
  socklen_t len = sizeof(addr);
  if (getsockname(fd, (struct sockaddr *)&addr, &len) != 0) {
    close(fd);
    return -1;
  }
  pthread_t thread;
  if (pthread_create(&thread, NULL, rebal_echo_main, (void *)(intptr_t)fd) != 0) {
    close(fd);
    return -1;
  }
  pthread_detach(thread);
  return (int32_t)ntohs(addr.sin_port);
}

static int32_t rebal_udp_status = 0;

int32_t rebal_udp_code(void) { return rebal_udp_status; }

static int rebal_udp_socket(void) {
  return socket(AF_INET, SOCK_DGRAM, 0);
}

int32_t rebal_udp_connect(moonbit_string_t host, int32_t host_len, int32_t port) {
  rebal_udp_status = 1;
  char *name = rebal_to_utf8(host, host_len);
  if (name == NULL || port < 1 || port > 65535) {
    free(name);
    return -1;
  }
  int fd = rebal_udp_socket();
  if (fd < 0) {
    free(name);
    return -1;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  if (inet_pton(AF_INET, name, &addr.sin_addr) != 1 ||
      connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    free(name);
    close(fd);
    return -1;
  }
  free(name);
  rebal_udp_status = 0;
  return fd;
}

int32_t rebal_udp_send(int32_t fd, moonbit_string_t text, int32_t text_len) {
  rebal_udp_status = 1;
  char *body = rebal_to_utf8(text, text_len);
  if (body == NULL || fd < 0) {
    free(body);
    return 1;
  }
  size_t len = strlen(body);
  ssize_t n = send(fd, body, len, 0);
  free(body);
  if (n < 0 || (size_t)n != len) {
    return 1;
  }
  rebal_udp_status = 0;
  return 0;
}

moonbit_string_t rebal_udp_recv(int32_t fd) {
  rebal_udp_status = 1;
  char *buf = malloc(65535);
  if (buf == NULL || fd < 0) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  ssize_t n = recv(fd, buf, 65535, 0);
  if (n < 0) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  int32_t units = rebal_utf8_units((unsigned char *)buf, (size_t)n);
  if (units < 0) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, (unsigned char *)buf, (size_t)n);
  free(buf);
  rebal_udp_status = 0;
  return text;
}

static void *rebal_udp_echo_main(void *arg) {
  int fd = (int)(intptr_t)arg;
  char buf[2048];
  struct sockaddr_in peer;
  socklen_t peer_len = sizeof(peer);
  ssize_t n = recvfrom(fd, buf, sizeof(buf), 0, (struct sockaddr *)&peer, &peer_len);
  if (n > 0) {
    sendto(fd, buf, (size_t)n, 0, (struct sockaddr *)&peer, peer_len);
  }
  close(fd);
  return NULL;
}

int32_t rebal_udp_echo(void) {
  int fd = rebal_udp_socket();
  if (fd < 0) {
    return -1;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = 0;
  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    close(fd);
    return -1;
  }
  socklen_t len = sizeof(addr);
  if (getsockname(fd, (struct sockaddr *)&addr, &len) != 0) {
    close(fd);
    return -1;
  }
  pthread_t thread;
  if (pthread_create(&thread, NULL, rebal_udp_echo_main, (void *)(intptr_t)fd) != 0) {
    close(fd);
    return -1;
  }
  pthread_detach(thread);
  return (int32_t)ntohs(addr.sin_port);
}

static int32_t rebal_http_status = 0;

int32_t rebal_http_code(void) { return rebal_http_status; }

static char *rebal_read_all(int fd, size_t *out_len) {
  size_t len = 0;
  size_t cap = 256;
  char *buf = malloc(cap);
  if (buf == NULL) {
    return NULL;
  }
  for (;;) {
    if (len + 1 >= cap) {
      cap *= 2;
      char *grown = realloc(buf, cap);
      if (grown == NULL) {
        free(buf);
        return NULL;
      }
      buf = grown;
    }
    ssize_t n = recv(fd, buf + len, cap - len - 1, 0);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      free(buf);
      return NULL;
    }
    if (n == 0) {
      break;
    }
    len += (size_t)n;
  }
  buf[len] = 0;
  *out_len = len;
  return buf;
}

moonbit_string_t rebal_http_get(
  moonbit_string_t host,
  int32_t host_len,
  int32_t port,
  moonbit_string_t path,
  int32_t path_len
) {
  rebal_http_status = 1;
  char *name = rebal_to_utf8(host, host_len);
  char *target = rebal_to_utf8(path, path_len);
  if (name == NULL || target == NULL) {
    free(name);
    free(target);
    return moonbit_make_string(0, 0);
  }
  int fd = rebal_tcp_socket();
  if (fd < 0) {
    free(name);
    free(target);
    return moonbit_make_string(0, 0);
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  if (inet_pton(AF_INET, name, &addr.sin_addr) != 1 ||
      connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    free(name);
    free(target);
    close(fd);
    return moonbit_make_string(0, 0);
  }
  char header[1024];
  int wrote = snprintf(
    header, sizeof(header),
    "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", target, name
  );
  free(name);
  free(target);
  if (wrote < 0 || (size_t)wrote >= sizeof(header)) {
    close(fd);
    return moonbit_make_string(0, 0);
  }
  size_t sent = 0;
  while (sent < (size_t)wrote) {
    ssize_t n = send(fd, header + sent, (size_t)wrote - sent, 0);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      close(fd);
      return moonbit_make_string(0, 0);
    }
    sent += (size_t)n;
  }
  size_t len = 0;
  char *buf = rebal_read_all(fd, &len);
  close(fd);
  if (buf == NULL) {
    return moonbit_make_string(0, 0);
  }
  if (strncmp(buf, "HTTP/", 5) != 0) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  char *status = strchr(buf, ' ');
  if (status == NULL || strncmp(status, " 200", 4) != 0) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  char *body = strstr(buf, "\r\n\r\n");
  if (body == NULL) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  body += 4;
  size_t body_len = len - (size_t)(body - buf);
  int32_t units = rebal_utf8_units((unsigned char *)body, body_len);
  if (units < 0) {
    free(buf);
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string(units, 0);
  rebal_fill_utf16(text, (unsigned char *)body, body_len);
  free(buf);
  rebal_http_status = 0;
  return text;
}

static int rebal_read_header(int fd) {
  char buf[2048];
  size_t len = 0;
  while (len + 1 < sizeof(buf)) {
    ssize_t n = recv(fd, buf + len, 1, 0);
    if (n <= 0) {
      return -1;
    }
    len += 1;
    if (len >= 4 && memcmp(buf + len - 4, "\r\n\r\n", 4) == 0) {
      return 0;
    }
  }
  return -1;
}

static void *rebal_http_main(void *arg) {
  int listen_fd = (int)(intptr_t)arg;
  struct sockaddr_in peer;
  socklen_t peer_len = sizeof(peer);
  int conn = accept(listen_fd, (struct sockaddr *)&peer, &peer_len);
  close(listen_fd);
  if (conn < 0) {
    return NULL;
  }
  if (rebal_read_header(conn) != 0) {
    close(conn);
    return NULL;
  }
  const char *response =
    "HTTP/1.0 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok";
  size_t total = strlen(response);
  size_t sent = 0;
  while (sent < total) {
    ssize_t n = send(conn, response + sent, total - sent, 0);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    sent += (size_t)n;
  }
  close(conn);
  return NULL;
}

int32_t rebal_http_serve(void) {
  int fd = rebal_tcp_socket();
  if (fd < 0) {
    return -1;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = 0;
  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0 ||
      listen(fd, 1) != 0) {
    close(fd);
    return -1;
  }
  socklen_t len = sizeof(addr);
  if (getsockname(fd, (struct sockaddr *)&addr, &len) != 0) {
    close(fd);
    return -1;
  }
  pthread_t thread;
  if (pthread_create(&thread, NULL, rebal_http_main, (void *)(intptr_t)fd) != 0) {
    close(fd);
    return -1;
  }
  pthread_detach(thread);
  return (int32_t)ntohs(addr.sin_port);
}

/* ---- TCP listen / accept / poll (async ports) ---- */

static int32_t rebal_tcp_listen_status = 0;
static int32_t rebal_tcp_bound_port = 0;

int32_t rebal_tcp_listen_code(void) { return rebal_tcp_listen_status; }

int32_t rebal_tcp_bound_port_get(void) { return rebal_tcp_bound_port; }

static int rebal_tcp_set_nonblock(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags < 0) {
    return -1;
  }
  return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

///|
/// Bind and listen. Empty host (len 0) means INADDR_ANY. Port 0 picks an
/// ephemeral port; call rebal_tcp_bound_port_get afterwards.
int32_t rebal_tcp_listen(moonbit_string_t host, int32_t host_len, int32_t port) {
  rebal_tcp_listen_status = 1;
  rebal_tcp_bound_port = 0;
  if (port < 0 || port > 65535) {
    return -1;
  }
  int fd = rebal_tcp_socket();
  if (fd < 0) {
    return -1;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  if (host_len <= 0) {
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
  } else {
    char *name = rebal_to_utf8(host, host_len);
    if (name == NULL || inet_pton(AF_INET, name, &addr.sin_addr) != 1) {
      free(name);
      close(fd);
      return -1;
    }
    free(name);
  }
  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0 ||
      listen(fd, 128) != 0 || rebal_tcp_set_nonblock(fd) != 0) {
    close(fd);
    return -1;
  }
  socklen_t len = sizeof(addr);
  if (getsockname(fd, (struct sockaddr *)&addr, &len) != 0) {
    close(fd);
    return -1;
  }
  rebal_tcp_bound_port = (int32_t)ntohs(addr.sin_port);
  rebal_tcp_listen_status = 0;
  return fd;
}

///|
/// Accept one connection without blocking. Returns the new fd, -1 if none
/// is ready, or -2 on error.
int32_t rebal_tcp_accept(int32_t listen_fd) {
  rebal_tcp_status = 1;
  if (listen_fd < 0) {
    return -2;
  }
  struct sockaddr_in peer;
  socklen_t peer_len = sizeof(peer);
  int conn = accept(listen_fd, (struct sockaddr *)&peer, &peer_len);
  if (conn < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      rebal_tcp_status = 0;
      return -1;
    }
    return -2;
  }
  if (rebal_tcp_set_nonblock(conn) != 0) {
    close(conn);
    return -2;
  }
  rebal_tcp_status = 0;
  return conn;
}

#define REBAL_POLL_MAX 64
static struct pollfd rebal_poll_fds[REBAL_POLL_MAX];
static int32_t rebal_poll_tags[REBAL_POLL_MAX];
static int32_t rebal_poll_count = 0;
static int32_t rebal_poll_ready_n = 0;
static int32_t rebal_poll_ready_fd[REBAL_POLL_MAX];
static int32_t rebal_poll_ready_tag[REBAL_POLL_MAX];

void rebal_poll_clear(void) {
  rebal_poll_count = 0;
  rebal_poll_ready_n = 0;
}

///|
/// tag: 1 = accept interest, 2 = read interest.
int32_t rebal_poll_add(int32_t fd, int32_t tag) {
  if (fd < 0 || rebal_poll_count >= REBAL_POLL_MAX) {
    return 1;
  }
  rebal_poll_fds[rebal_poll_count].fd = fd;
  rebal_poll_fds[rebal_poll_count].events = POLLIN;
  rebal_poll_fds[rebal_poll_count].revents = 0;
  rebal_poll_tags[rebal_poll_count] = tag;
  rebal_poll_count += 1;
  return 0;
}

///|
/// Wait up to timeout_ms. Returns the number of ready entries (0 on timeout).
int32_t rebal_poll_wait(int32_t timeout_ms) {
  rebal_poll_ready_n = 0;
  if (rebal_poll_count == 0) {
    if (timeout_ms > 0) {
      usleep((useconds_t)timeout_ms * 1000U);
    }
    return 0;
  }
  int n = poll(rebal_poll_fds, (nfds_t)rebal_poll_count, timeout_ms);
  if (n <= 0) {
    return 0;
  }
  for (int32_t i = 0; i < rebal_poll_count; i++) {
    if (rebal_poll_fds[i].revents & (POLLIN | POLLHUP | POLLERR)) {
      rebal_poll_ready_fd[rebal_poll_ready_n] = rebal_poll_fds[i].fd;
      rebal_poll_ready_tag[rebal_poll_ready_n] = rebal_poll_tags[i];
      rebal_poll_ready_n += 1;
    }
  }
  return rebal_poll_ready_n;
}

int32_t rebal_poll_ready_count(void) { return rebal_poll_ready_n; }

int32_t rebal_poll_ready_fd_at(int32_t index) {
  if (index < 0 || index >= rebal_poll_ready_n) {
    return -1;
  }
  return rebal_poll_ready_fd[index];
}

int32_t rebal_poll_ready_tag_at(int32_t index) {
  if (index < 0 || index >= rebal_poll_ready_n) {
    return 0;
  }
  return rebal_poll_ready_tag[index];
}

///|
/// Non-blocking recv into a latin-1 MoonBit string (one code unit per byte).
/// Empty string with status 0 and eof flag via rebal_tcp_code: 0=ok, 1=err, 2=eof, 3=eagain.
moonbit_string_t rebal_tcp_recv_bytes(int32_t fd) {
  rebal_tcp_status = 1;
  if (fd < 0) {
    return moonbit_make_string(0, 0);
  }
  unsigned char buf[8192];
  ssize_t n = recv(fd, buf, sizeof(buf), 0);
  if (n < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      rebal_tcp_status = 3;
      return moonbit_make_string(0, 0);
    }
    return moonbit_make_string(0, 0);
  }
  if (n == 0) {
    rebal_tcp_status = 2;
    return moonbit_make_string(0, 0);
  }
  moonbit_string_t text = moonbit_make_string((int32_t)n, 0);
  for (ssize_t i = 0; i < n; i++) {
    text[i] = buf[i];
  }
  rebal_tcp_status = 0;
  return text;
}

///|
/// Send raw bytes carried in a latin-1 MoonBit string.
int32_t rebal_tcp_send_bytes(
  int32_t fd,
  moonbit_string_t data,
  int32_t data_len
) {
  rebal_tcp_status = 1;
  if (fd < 0 || data_len < 0) {
    return 1;
  }
  size_t sent = 0;
  while (sent < (size_t)data_len) {
    char chunk[1024];
    size_t left = (size_t)data_len - sent;
    size_t n = left > sizeof(chunk) ? sizeof(chunk) : left;
    for (size_t i = 0; i < n; i++) {
      chunk[i] = (char)(data[sent + i] & 0xff);
    }
    ssize_t w = send(fd, chunk, n, 0);
    if (w < 0) {
      if (errno == EINTR) {
        continue;
      }
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        continue;
      }
      return 1;
    }
    sent += (size_t)w;
  }
  rebal_tcp_status = 0;
  return 0;
}

/* ---- TCP probe client (tests listen/accept/awake) ---- */

static char rebal_probe_got[4096];
static int32_t rebal_probe_got_len = 0;
static int32_t rebal_probe_status = 1;

struct rebal_probe_job {
  int32_t port;
  char *data;
  int32_t data_len;
};

static void *rebal_probe_main(void *arg) {
  struct rebal_probe_job *job = (struct rebal_probe_job *)arg;
  usleep(20000);
  int fd = rebal_tcp_socket();
  if (fd < 0) {
    free(job->data);
    free(job);
    rebal_probe_status = 1;
    return NULL;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = htons((uint16_t)job->port);
  if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    close(fd);
    free(job->data);
    free(job);
    rebal_probe_status = 1;
    return NULL;
  }
  size_t sent = 0;
  while (sent < (size_t)job->data_len) {
    ssize_t n = send(fd, job->data + sent, (size_t)job->data_len - sent, 0);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      close(fd);
      free(job->data);
      free(job);
      rebal_probe_status = 1;
      return NULL;
    }
    sent += (size_t)n;
  }
  rebal_probe_got_len = 0;
  while (rebal_probe_got_len < (int32_t)sizeof(rebal_probe_got)) {
    ssize_t n = recv(
      fd,
      rebal_probe_got + rebal_probe_got_len,
      sizeof(rebal_probe_got) - (size_t)rebal_probe_got_len,
      0
    );
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    if (n == 0) {
      break;
    }
    rebal_probe_got_len += (int32_t)n;
  }
  close(fd);
  free(job->data);
  free(job);
  rebal_probe_status = 0;
  return NULL;
}

///|
/// Spawn a client that connects to 127.0.0.1:port, sends `data`, and stores
/// the reply for `rebal_tcp_probe_result`.
int32_t rebal_tcp_probe(int32_t port, moonbit_string_t data, int32_t data_len) {
  rebal_probe_status = 1;
  rebal_probe_got_len = 0;
  if (port < 1 || port > 65535 || data_len < 0) {
    return 1;
  }
  struct rebal_probe_job *job = malloc(sizeof(*job));
  if (job == NULL) {
    return 1;
  }
  job->port = port;
  job->data_len = data_len;
  job->data = malloc((size_t)data_len + 1U);
  if (job->data == NULL) {
    free(job);
    return 1;
  }
  for (int32_t i = 0; i < data_len; i++) {
    job->data[i] = (char)(data[i] & 0xff);
  }
  job->data[data_len] = 0;
  pthread_t thread;
  if (pthread_create(&thread, NULL, rebal_probe_main, job) != 0) {
    free(job->data);
    free(job);
    return 1;
  }
  pthread_detach(thread);
  return 0;
}

int32_t rebal_tcp_probe_code(void) { return rebal_probe_status; }

moonbit_string_t rebal_tcp_probe_result(void) {
  moonbit_string_t text = moonbit_make_string(rebal_probe_got_len, 0);
  for (int32_t i = 0; i < rebal_probe_got_len; i++) {
    text[i] = (uint16_t)(unsigned char)rebal_probe_got[i];
  }
  return text;
}
