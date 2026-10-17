#include <dirent.h>
#include <errno.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

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

static int32_t rebal_call_result = 0;

int32_t rebal_call_code(void) { return rebal_call_result; }

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
  int wait_flag = (flags & 1) != 0;
  int shell = (flags & 2) != 0;
  int capture = (flags & 4) != 0;
  if (capture) {
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
  if (out_pipe[0] >= 0) {
    close(out_pipe[1]);
    char tmp[1024];
    ssize_t got = 0;
    while ((got = read(out_pipe[0], tmp, sizeof tmp)) > 0) {
      rebal_add_bytes(&captured, &captured_len, &captured_cap, tmp, (size_t)got);
    }
    close(out_pipe[0]);
  }
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

int32_t rebal_clock_year(void) { return rebal_year; }
int32_t rebal_clock_month(void) { return rebal_month; }
int32_t rebal_clock_day(void) { return rebal_day; }
int32_t rebal_clock_zone(void) { return rebal_zone; }
int32_t rebal_clock_weekday(void) { return rebal_weekday; }
int32_t rebal_clock_yearday(void) { return rebal_yearday; }
double rebal_clock_seconds(void) { return rebal_seconds; }
