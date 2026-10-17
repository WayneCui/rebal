#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <moonbit.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

typedef struct rebal_ssl_ctx rebal_ssl_ctx;
typedef struct rebal_ssl rebal_ssl;
typedef struct rebal_ssl_method rebal_ssl_method;
typedef struct rebal_pkey rebal_pkey;
typedef struct rebal_x509 rebal_x509;
typedef struct rebal_x509_name rebal_x509_name;
typedef struct rebal_asn1_int rebal_asn1_int;
typedef struct rebal_asn1_time rebal_asn1_time;
typedef struct rebal_evp_md rebal_evp_md;

static rebal_ssl_method *(*tls_client_method)(void);
static rebal_ssl_method *(*tls_server_method)(void);
static rebal_ssl_ctx *(*ssl_ctx_new)(const rebal_ssl_method *);
static void (*ssl_ctx_free)(rebal_ssl_ctx *);
static void (*ssl_ctx_set_verify)(rebal_ssl_ctx *, int, void *);
static int (*ssl_ctx_use_certificate)(rebal_ssl_ctx *, rebal_x509 *);
static int (*ssl_ctx_use_private_key)(rebal_ssl_ctx *, rebal_pkey *);
static rebal_ssl *(*ssl_new)(rebal_ssl_ctx *);
static void (*ssl_free)(rebal_ssl *);
static int (*ssl_set_fd)(rebal_ssl *, int);
static int (*ssl_connect)(rebal_ssl *);
static int (*ssl_accept)(rebal_ssl *);
static int (*ssl_read)(rebal_ssl *, void *, int);
static int (*ssl_write)(rebal_ssl *, const void *, int);
static int (*ssl_shutdown)(rebal_ssl *);
static rebal_pkey *(*evp_pkey_q_keygen)(void *, const char *, const char *, ...);
static void (*evp_pkey_free)(rebal_pkey *);
static rebal_x509 *(*x509_new)(void);
static void (*x509_free)(rebal_x509 *);
static int (*x509_set_version)(rebal_x509 *, long);
static rebal_asn1_int *(*x509_get_serial)(rebal_x509 *);
static int (*asn1_integer_set)(rebal_asn1_int *, long);
static rebal_asn1_time *(*x509_not_before)(const rebal_x509 *);
static rebal_asn1_time *(*x509_not_after)(const rebal_x509 *);
static rebal_asn1_time *(*x509_gmtime_adj)(rebal_asn1_time *, long);
static int (*x509_set_pubkey)(rebal_x509 *, rebal_pkey *);
static rebal_x509_name *(*x509_subject)(const rebal_x509 *);
static int (*x509_name_add)(
  rebal_x509_name *,
  const char *,
  int,
  const unsigned char *,
  int,
  int,
  int
);
static int (*x509_set_issuer)(rebal_x509 *, const rebal_x509_name *);
static int (*x509_sign)(rebal_x509 *, rebal_pkey *, const rebal_evp_md *);
static const rebal_evp_md *(*evp_sha256)(void);

extern char *rebal_to_utf8(const uint16_t *src, int32_t len);
extern int32_t rebal_utf8_units(const unsigned char *data, size_t size);
extern void rebal_fill_utf16(uint16_t *dst, const unsigned char *data, size_t size);

static int bind_sym(void *lib, const char *name, void *slot) {
  void *found = dlsym(lib, name);
  if (found == NULL) {
    return -1;
  }
  memcpy(slot, &found, sizeof(found));
  return 0;
}

static int load_one(void **lib, const char *path) {
  if (*lib != NULL) {
    return 0;
  }
  *lib = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
  return *lib == NULL ? -1 : 0;
}

static void *crypto_lib = NULL;
static void *ssl_lib = NULL;
static int tls_ready = 0;

static int load_tls(void) {
  if (tls_ready) {
    return 0;
  }
  if (load_one(&crypto_lib, "/opt/homebrew/opt/openssl/lib/libcrypto.dylib") != 0 &&
      load_one(&crypto_lib, "/usr/local/opt/openssl/lib/libcrypto.dylib") != 0 &&
      load_one(&crypto_lib, "libcrypto.dylib") != 0) {
    return -1;
  }
  if (load_one(&ssl_lib, "/opt/homebrew/opt/openssl/lib/libssl.dylib") != 0 &&
      load_one(&ssl_lib, "/usr/local/opt/openssl/lib/libssl.dylib") != 0 &&
      load_one(&ssl_lib, "libssl.dylib") != 0) {
    return -1;
  }
  if (bind_sym(ssl_lib, "TLS_client_method", &tls_client_method) != 0 ||
      bind_sym(ssl_lib, "TLS_server_method", &tls_server_method) != 0 ||
      bind_sym(ssl_lib, "SSL_CTX_new", &ssl_ctx_new) != 0 ||
      bind_sym(ssl_lib, "SSL_CTX_free", &ssl_ctx_free) != 0 ||
      bind_sym(ssl_lib, "SSL_CTX_set_verify", &ssl_ctx_set_verify) != 0 ||
      bind_sym(ssl_lib, "SSL_CTX_use_certificate", &ssl_ctx_use_certificate) != 0 ||
      bind_sym(ssl_lib, "SSL_CTX_use_PrivateKey", &ssl_ctx_use_private_key) != 0 ||
      bind_sym(ssl_lib, "SSL_new", &ssl_new) != 0 ||
      bind_sym(ssl_lib, "SSL_free", &ssl_free) != 0 ||
      bind_sym(ssl_lib, "SSL_set_fd", &ssl_set_fd) != 0 ||
      bind_sym(ssl_lib, "SSL_connect", &ssl_connect) != 0 ||
      bind_sym(ssl_lib, "SSL_accept", &ssl_accept) != 0 ||
      bind_sym(ssl_lib, "SSL_read", &ssl_read) != 0 ||
      bind_sym(ssl_lib, "SSL_write", &ssl_write) != 0 ||
      bind_sym(ssl_lib, "SSL_shutdown", &ssl_shutdown) != 0 ||
      bind_sym(crypto_lib, "EVP_PKEY_Q_keygen", &evp_pkey_q_keygen) != 0 ||
      bind_sym(crypto_lib, "EVP_PKEY_free", &evp_pkey_free) != 0 ||
      bind_sym(crypto_lib, "X509_new", &x509_new) != 0 ||
      bind_sym(crypto_lib, "X509_free", &x509_free) != 0 ||
      bind_sym(crypto_lib, "X509_set_version", &x509_set_version) != 0 ||
      bind_sym(crypto_lib, "X509_get_serialNumber", &x509_get_serial) != 0 ||
      bind_sym(crypto_lib, "ASN1_INTEGER_set", &asn1_integer_set) != 0 ||
      bind_sym(crypto_lib, "X509_getm_notBefore", &x509_not_before) != 0 ||
      bind_sym(crypto_lib, "X509_getm_notAfter", &x509_not_after) != 0 ||
      bind_sym(crypto_lib, "X509_gmtime_adj", &x509_gmtime_adj) != 0 ||
      bind_sym(crypto_lib, "X509_set_pubkey", &x509_set_pubkey) != 0 ||
      bind_sym(crypto_lib, "X509_get_subject_name", &x509_subject) != 0 ||
      bind_sym(crypto_lib, "X509_NAME_add_entry_by_txt", &x509_name_add) != 0 ||
      bind_sym(crypto_lib, "X509_set_issuer_name", &x509_set_issuer) != 0 ||
      bind_sym(crypto_lib, "X509_sign", &x509_sign) != 0 ||
      bind_sym(crypto_lib, "EVP_sha256", &evp_sha256) != 0) {
    return -1;
  }
  tls_ready = 1;
  return 0;
}

static rebal_ssl_ctx *server_ctx(void) {
  rebal_pkey *pkey = evp_pkey_q_keygen(NULL, NULL, "EC", "P-256");
  rebal_x509 *cert = pkey == NULL ? NULL : x509_new();
  if (cert == NULL) {
    if (pkey != NULL) {
      evp_pkey_free(pkey);
    }
    return NULL;
  }
  x509_set_version(cert, 2);
  asn1_integer_set(x509_get_serial(cert), 1);
  x509_gmtime_adj(x509_not_before(cert), 0);
  x509_gmtime_adj(x509_not_after(cert), 24 * 60 * 60);
  x509_set_pubkey(cert, pkey);
  rebal_x509_name *name = x509_subject(cert);
  x509_name_add(
    name, "CN", 0x1001, (const unsigned char *)"127.0.0.1", -1, -1, 0
  );
  x509_set_issuer(cert, name);
  rebal_ssl_ctx *ctx = NULL;
  if (x509_sign(cert, pkey, evp_sha256()) != 0) {
    ctx = ssl_ctx_new(tls_server_method());
    if (ctx == NULL || ssl_ctx_use_certificate(ctx, cert) != 1 ||
        ssl_ctx_use_private_key(ctx, pkey) != 1) {
      ssl_ctx_free(ctx);
      ctx = NULL;
    }
  }
  x509_free(cert);
  evp_pkey_free(pkey);
  return ctx;
}

#define REBAL_TLS_SLOTS 8

struct TlsSlot {
  int used;
  int fd;
  rebal_ssl *ssl;
  rebal_ssl_ctx *ctx;
};

static struct TlsSlot tls_slots[REBAL_TLS_SLOTS];
static int32_t rebal_tls_status = 1;

int32_t rebal_tls_code(void) { return rebal_tls_status; }

static int alloc_slot(void) {
  for (int i = 0; i < REBAL_TLS_SLOTS; i++) {
    if (!tls_slots[i].used) {
      tls_slots[i].used = 1;
      return i;
    }
  }
  return -1;
}

static void drop_conn(int fd, rebal_ssl *ssl, rebal_ssl_ctx *ctx) {
  if (ssl != NULL) {
    ssl_shutdown(ssl);
    ssl_free(ssl);
  }
  if (ctx != NULL) {
    ssl_ctx_free(ctx);
  }
  if (fd >= 0) {
    close(fd);
  }
}

static int connect_ipv4(const char *host, int port) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return -1;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  if (inet_pton(AF_INET, host, &addr.sin_addr) != 1 ||
      connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    close(fd);
    return -1;
  }
  return fd;
}

int32_t rebal_tls_connect(
  moonbit_string_t host,
  int32_t host_len,
  int32_t port,
  int32_t verify
) {
  rebal_tls_status = 1;
  if (load_tls() != 0 || port < 1 || port > 65535) {
    return -1;
  }
  char *name = rebal_to_utf8(host, host_len);
  if (name == NULL) {
    return -1;
  }
  int fd = connect_ipv4(name, port);
  free(name);
  if (fd < 0) {
    return -1;
  }
  rebal_ssl_ctx *ctx = ssl_ctx_new(tls_client_method());
  if (ctx == NULL) {
    close(fd);
    return -1;
  }
  ssl_ctx_set_verify(ctx, verify ? 1 : 0, NULL);
  rebal_ssl *ssl = ssl_new(ctx);
  if (ssl == NULL || ssl_set_fd(ssl, fd) != 1 || ssl_connect(ssl) != 1) {
    drop_conn(fd, ssl, ctx);
    return -1;
  }
  int slot = alloc_slot();
  if (slot < 0) {
    drop_conn(fd, ssl, ctx);
    return -1;
  }
  tls_slots[slot].fd = fd;
  tls_slots[slot].ssl = ssl;
  tls_slots[slot].ctx = ctx;
  rebal_tls_status = 0;
  return slot;
}

int32_t rebal_tls_send(int32_t slot, moonbit_string_t text, int32_t text_len) {
  rebal_tls_status = 1;
  if (slot < 0 || slot >= REBAL_TLS_SLOTS || !tls_slots[slot].used) {
    return 1;
  }
  char *body = rebal_to_utf8(text, text_len);
  if (body == NULL) {
    return 1;
  }
  size_t len = strlen(body);
  size_t sent = 0;
  while (sent < len) {
    int n = ssl_write(tls_slots[slot].ssl, body + sent, (int)(len - sent));
    if (n <= 0) {
      free(body);
      return 1;
    }
    sent += (size_t)n;
  }
  free(body);
  rebal_tls_status = 0;
  return 0;
}

moonbit_string_t rebal_tls_recv(int32_t slot) {
  rebal_tls_status = 1;
  if (slot < 0 || slot >= REBAL_TLS_SLOTS || !tls_slots[slot].used) {
    return moonbit_make_string(0, 0);
  }
  size_t len = 0;
  size_t cap = 64;
  char *buf = malloc(cap);
  if (buf == NULL) {
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
    int n = ssl_read(tls_slots[slot].ssl, buf + len, (int)(cap - len));
    if (n <= 0) {
      if (n < 0) {
        free(buf);
        return moonbit_make_string(0, 0);
      }
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
  rebal_tls_status = 0;
  return text;
}

int32_t rebal_tls_close(int32_t slot) {
  if (slot < 0 || slot >= REBAL_TLS_SLOTS || !tls_slots[slot].used) {
    return 0;
  }
  drop_conn(tls_slots[slot].fd, tls_slots[slot].ssl, tls_slots[slot].ctx);
  tls_slots[slot].used = 0;
  tls_slots[slot].fd = -1;
  tls_slots[slot].ssl = NULL;
  tls_slots[slot].ctx = NULL;
  return 0;
}

struct TlsJob {
  rebal_ssl_ctx *ctx;
  int fd;
};

static void echo_line(rebal_ssl *ssl) {
  char buf[1024];
  int got = 0;
  while (got < (int)sizeof(buf)) {
    int n = ssl_read(ssl, buf + got, 1);
    if (n <= 0) {
      break;
    }
    got += n;
    if (buf[got - 1] == '\n') {
      break;
    }
  }
  int sent = 0;
  while (sent < got) {
    int n = ssl_write(ssl, buf + sent, got - sent);
    if (n <= 0) {
      break;
    }
    sent += n;
  }
}

static void *tls_serve_main(void *arg) {
  struct TlsJob *job = arg;
  struct sockaddr_in peer;
  socklen_t peer_len = sizeof(peer);
  int conn = accept(job->fd, (struct sockaddr *)&peer, &peer_len);
  close(job->fd);
  if (conn >= 0) {
    rebal_ssl *ssl = ssl_new(job->ctx);
    if (ssl != NULL && ssl_set_fd(ssl, conn) == 1 && ssl_accept(ssl) == 1) {
      echo_line(ssl);
    }
    if (ssl != NULL) {
      ssl_shutdown(ssl);
      ssl_free(ssl);
    }
    close(conn);
  }
  ssl_ctx_free(job->ctx);
  free(job);
  return NULL;
}

int32_t rebal_tls_serve(void) {
  if (load_tls() != 0) {
    return -1;
  }
  rebal_ssl_ctx *ctx = server_ctx();
  if (ctx == NULL) {
    return -1;
  }
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    ssl_ctx_free(ctx);
    return -1;
  }
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = 0;
  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0 || listen(fd, 1) != 0) {
    close(fd);
    ssl_ctx_free(ctx);
    return -1;
  }
  socklen_t len = sizeof(addr);
  if (getsockname(fd, (struct sockaddr *)&addr, &len) != 0) {
    close(fd);
    ssl_ctx_free(ctx);
    return -1;
  }
  struct TlsJob *job = malloc(sizeof(*job));
  if (job == NULL) {
    close(fd);
    ssl_ctx_free(ctx);
    return -1;
  }
  job->ctx = ctx;
  job->fd = fd;
  pthread_t thread;
  if (pthread_create(&thread, NULL, tls_serve_main, job) != 0) {
    close(fd);
    ssl_ctx_free(ctx);
    free(job);
    return -1;
  }
  pthread_detach(thread);
  return (int32_t)ntohs(addr.sin_port);
}
