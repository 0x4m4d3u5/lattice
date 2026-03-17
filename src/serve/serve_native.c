/*
 * serve_native.c — minimal development HTTP server for lattice
 *
 * Provides:
 *   lattice_serve_start(port, root)   — start server in background thread
 *   lattice_serve_broadcast_reload()  — push SSE reload to all clients
 *   lattice_serve_stop()              — shut down server
 *
 * SSE endpoint: GET /__lattice_reload
 * File serving: everything else, from the root directory
 * HTML injection: live-reload <script> injected before </body>
 */

#ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#  include <winsock2.h>
#  include <ws2tcpip.h>
#  pragma comment(lib, "ws2_32.lib")
   typedef SOCKET sock_t;
#  define INVALID_SOCK INVALID_SOCKET
#  define sock_close(s) closesocket(s)
#  define sock_write(s,b,n) send(s, b, n, 0)
#  define sock_read(s,b,n)  recv(s, b, n, 0)
#else
#  include <arpa/inet.h>
#  include <errno.h>
#  include <fcntl.h>
#  include <netinet/in.h>
#  include <pthread.h>
#  include <signal.h>
#  include <sys/select.h>
#  include <sys/socket.h>
#  include <sys/stat.h>
#  include <sys/types.h>
#  include <unistd.h>
   typedef int sock_t;
#  define INVALID_SOCK (-1)
#  define sock_close(s) close(s)
#  define sock_write(s,b,n) write(s, b, n)
#  define sock_read(s,b,n)  read(s, b, n)
#endif

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ── constants ─────────────────────────────────────────────────────────────── */

#define MAX_SSE_CLIENTS  64
#define REQ_BUF_SIZE     8192
#define FILE_BUF_SIZE    65536
#define PATH_MAX_SIZE    4096

static const char RELOAD_SCRIPT[] =
    "<script>new EventSource('/__lattice_reload')"
    ".onmessage=function(){location.reload()}</script>";

static const char SSE_HEADERS[] =
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: text/event-stream\r\n"
    "Cache-Control: no-cache\r\n"
    "Connection: keep-alive\r\n"
    "Access-Control-Allow-Origin: *\r\n"
    "\r\n";

static const char RELOAD_EVENT[] = "data: reload\n\n";

static const char NOT_FOUND[] =
    "HTTP/1.1 404 Not Found\r\n"
    "Content-Type: text/plain\r\n"
    "Content-Length: 9\r\n"
    "Connection: close\r\n"
    "\r\n"
    "Not Found";

static const char BAD_REQUEST[] =
    "HTTP/1.1 400 Bad Request\r\n"
    "Content-Type: text/plain\r\n"
    "Content-Length: 11\r\n"
    "Connection: close\r\n"
    "\r\n"
    "Bad Request";

/* ── global server state ───────────────────────────────────────────────────── */

static sock_t           g_listen_fd  = INVALID_SOCK;
static sock_t           g_sse_fds[MAX_SSE_CLIENTS];
static int              g_sse_count  = 0;
static char             g_root[PATH_MAX_SIZE];
static volatile int     g_running    = 0;

#ifndef _WIN32
static pthread_t        g_thread;
static pthread_mutex_t  g_mutex      = PTHREAD_MUTEX_INITIALIZER;
static int              g_ctrl[2]    = {-1, -1}; /* shutdown pipe */
#else
static HANDLE           g_thread     = NULL;
static HANDLE           g_mutex;
static HANDLE           g_ctrl_event = NULL;
#endif

/* ── MIME types ────────────────────────────────────────────────────────────── */

static const char *mime_for_path(const char *path) {
    const char *dot = strrchr(path, '.');
    if (!dot) return "application/octet-stream";
    dot++;
    if (strcmp(dot, "html") == 0 || strcmp(dot, "htm") == 0)
        return "text/html; charset=utf-8";
    if (strcmp(dot, "css")  == 0) return "text/css; charset=utf-8";
    if (strcmp(dot, "js")   == 0) return "text/javascript; charset=utf-8";
    if (strcmp(dot, "json") == 0) return "application/json";
    if (strcmp(dot, "xml")  == 0) return "application/xml";
    if (strcmp(dot, "png")  == 0) return "image/png";
    if (strcmp(dot, "jpg")  == 0 || strcmp(dot, "jpeg") == 0)
        return "image/jpeg";
    if (strcmp(dot, "gif")  == 0) return "image/gif";
    if (strcmp(dot, "svg")  == 0) return "image/svg+xml";
    if (strcmp(dot, "ico")  == 0) return "image/x-icon";
    if (strcmp(dot, "woff") == 0) return "font/woff";
    if (strcmp(dot, "woff2")== 0) return "font/woff2";
    if (strcmp(dot, "ttf")  == 0) return "font/ttf";
    if (strcmp(dot, "txt")  == 0) return "text/plain; charset=utf-8";
    return "application/octet-stream";
}

static int is_html_mime(const char *mime) {
    return strncmp(mime, "text/html", 9) == 0;
}

/* ── URL decode ────────────────────────────────────────────────────────────── */

static void url_decode(const char *src, char *dst, size_t dst_size) {
    size_t di = 0;
    for (size_t si = 0; src[si] && di + 1 < dst_size; si++) {
        if (src[si] == '%' && src[si+1] && src[si+2]) {
            char hex[3] = { src[si+1], src[si+2], 0 };
            dst[di++] = (char)strtol(hex, NULL, 16);
            si += 2;
        } else if (src[si] == '+') {
            dst[di++] = ' ';
        } else {
            dst[di++] = src[si];
        }
    }
    dst[di] = '\0';
}

/* ── safe path resolution ──────────────────────────────────────────────────── */

/* Returns 1 if fs_path safely resolves inside root, 0 otherwise. */
static int resolve_path(const char *url_path, char *fs_path, size_t fs_size) {
    char decoded[PATH_MAX_SIZE];
    url_decode(url_path, decoded, sizeof(decoded));

    /* strip query string */
    char *q = strchr(decoded, '?');
    if (q) *q = '\0';

    /* collapse .. segments */
    char canonical[PATH_MAX_SIZE];
    size_t ci = 0;
    for (size_t i = 0; decoded[i] && ci + 1 < sizeof(canonical); i++) {
        if (decoded[i] == '.' && decoded[i+1] == '.' &&
            (decoded[i+2] == '/' || decoded[i+2] == '\0')) {
            /* step back one segment */
            if (ci > 0) ci--;
            while (ci > 0 && canonical[ci-1] != '/') ci--;
            i += 2;
            if (!decoded[i]) break;
        } else {
            canonical[ci++] = decoded[i];
        }
    }
    canonical[ci] = '\0';

    size_t root_len = strlen(g_root);
    if (snprintf(fs_path, fs_size, "%s%s", g_root, canonical) < 0)
        return 0;

    /* must start with root */
    return strncmp(fs_path, g_root, root_len) == 0;
}

/* ── file-serving response ─────────────────────────────────────────────────── */

static void send_file(sock_t fd, const char *fs_path) {
    const char *mime = mime_for_path(fs_path);
    int inject = is_html_mime(mime);
    size_t script_len = inject ? strlen(RELOAD_SCRIPT) : 0;

    FILE *f = fopen(fs_path, "rb");
    if (!f) {
        sock_write(fd, NOT_FOUND, strlen(NOT_FOUND));
        return;
    }

    /* read entire file */
    fseek(f, 0, SEEK_END);
    long file_size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (file_size < 0) { fclose(f); sock_write(fd, NOT_FOUND, strlen(NOT_FOUND)); return; }

    char *body = (char *)malloc((size_t)file_size + script_len + 1);
    if (!body) { fclose(f); sock_write(fd, NOT_FOUND, strlen(NOT_FOUND)); return; }

    size_t nread = fread(body, 1, (size_t)file_size, f);
    fclose(f);
    body[nread] = '\0';

    size_t content_len = nread;
    size_t inject_at   = nread; /* default: append */

    if (inject) {
        /* find </body> case-insensitively */
        for (size_t i = 0; i + 7 <= nread; i++) {
            if ((body[i]   == '<') &&
                (body[i+1] == '/' || body[i+1] == '/') &&
                ((body[i+1] == '/' &&
                  (body[i+2]=='b'||body[i+2]=='B') &&
                  (body[i+3]=='o'||body[i+3]=='O') &&
                  (body[i+4]=='d'||body[i+4]=='D') &&
                  (body[i+5]=='y'||body[i+5]=='Y') &&
                  body[i+6] == '>'))) {
                inject_at = i;
                break;
            }
        }
        /* shift body[inject_at..] right by script_len */
        memmove(body + inject_at + script_len, body + inject_at, nread - inject_at + 1);
        memcpy(body + inject_at, RELOAD_SCRIPT, script_len);
        content_len = nread + script_len;
    }

    char header[512];
    int hlen = snprintf(header, sizeof(header),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: %s\r\n"
        "Content-Length: %zu\r\n"
        "Cache-Control: no-cache\r\n"
        "Connection: close\r\n"
        "\r\n",
        mime, content_len);
    if (hlen > 0) sock_write(fd, header, (size_t)hlen);
    sock_write(fd, body, content_len);
    free(body);
}

/* ── request handler ───────────────────────────────────────────────────────── */

static void handle_connection(sock_t client_fd) {
    char buf[REQ_BUF_SIZE];
    ssize_t n = sock_read(client_fd, buf, sizeof(buf) - 1);
    if (n <= 0) { sock_close(client_fd); return; }
    buf[n] = '\0';

    /* parse first line: METHOD SP path SP HTTP/... */
    char method[16] = {0};
    char url_path[PATH_MAX_SIZE] = {0};
    sscanf(buf, "%15s %4095s", method, url_path);

    if (strcmp(method, "GET") != 0) {
        sock_write(client_fd, BAD_REQUEST, strlen(BAD_REQUEST));
        sock_close(client_fd);
        return;
    }

    /* strip query string from path for routing */
    char clean_path[PATH_MAX_SIZE];
    strncpy(clean_path, url_path, sizeof(clean_path) - 1);
    clean_path[sizeof(clean_path)-1] = '\0';
    char *q = strchr(clean_path, '?');
    if (q) *q = '\0';

    /* SSE reload endpoint */
    if (strcmp(clean_path, "/__lattice_reload") == 0) {
        sock_write(client_fd, SSE_HEADERS, strlen(SSE_HEADERS));
        /* send a keepalive comment immediately */
        sock_write(client_fd, ": connected\n\n", 13);
#ifndef _WIN32
        pthread_mutex_lock(&g_mutex);
#else
        WaitForSingleObject(g_mutex, INFINITE);
#endif
        if (g_sse_count < MAX_SSE_CLIENTS) {
            g_sse_fds[g_sse_count++] = client_fd;
        } else {
            /* too many clients — close */
#ifndef _WIN32
            pthread_mutex_unlock(&g_mutex);
#else
            ReleaseMutex(g_mutex);
#endif
            sock_close(client_fd);
            return;
        }
#ifndef _WIN32
        pthread_mutex_unlock(&g_mutex);
#else
        ReleaseMutex(g_mutex);
#endif
        /* do NOT close client_fd — it stays in g_sse_fds */
        return;
    }

    /* static file */
    char fs_path[PATH_MAX_SIZE];
    if (!resolve_path(clean_path, fs_path, sizeof(fs_path))) {
        sock_write(client_fd, NOT_FOUND, strlen(NOT_FOUND));
        sock_close(client_fd);
        return;
    }

    /* stat to check existence and whether it's a directory */
    struct stat st;
    if (stat(fs_path, &st) != 0) {
        sock_write(client_fd, NOT_FOUND, strlen(NOT_FOUND));
        sock_close(client_fd);
        return;
    }

    if (S_ISDIR(st.st_mode)) {
        /* try index.html */
        size_t cur_len = strlen(fs_path);
        if (cur_len + 11 < PATH_MAX_SIZE) {
            if (fs_path[cur_len-1] != '/') {
                fs_path[cur_len]   = '/';
                fs_path[cur_len+1] = '\0';
            }
            strncat(fs_path, "index.html", PATH_MAX_SIZE - strlen(fs_path) - 1);
            if (stat(fs_path, &st) != 0 || S_ISDIR(st.st_mode)) {
                sock_write(client_fd, NOT_FOUND, strlen(NOT_FOUND));
                sock_close(client_fd);
                return;
            }
        } else {
            sock_write(client_fd, NOT_FOUND, strlen(NOT_FOUND));
            sock_close(client_fd);
            return;
        }
    }

    send_file(client_fd, fs_path);
    sock_close(client_fd);
}

/* ── server thread ─────────────────────────────────────────────────────────── */

#ifndef _WIN32
static void *server_thread_func(void *arg) {
    (void)arg;
    while (g_running) {
        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(g_listen_fd, &rfds);
        FD_SET(g_ctrl[0],   &rfds);
        int max_fd = g_listen_fd > g_ctrl[0] ? (int)g_listen_fd : g_ctrl[0];

        pthread_mutex_lock(&g_mutex);
        for (int i = 0; i < g_sse_count; i++) {
            FD_SET(g_sse_fds[i], &rfds);
            if ((int)g_sse_fds[i] > max_fd) max_fd = (int)g_sse_fds[i];
        }
        pthread_mutex_unlock(&g_mutex);

        struct timeval tv = {0, 200000}; /* 200 ms */
        int ret = select(max_fd + 1, &rfds, NULL, NULL, &tv);
        if (ret < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (ret == 0) continue;

        /* shutdown signal */
        if (FD_ISSET(g_ctrl[0], &rfds)) break;

        /* accept new connection */
        if (FD_ISSET(g_listen_fd, &rfds)) {
            sock_t cfd = accept(g_listen_fd, NULL, NULL);
            if (cfd != INVALID_SOCK) handle_connection(cfd);
        }

        /* detect disconnected SSE clients */
        pthread_mutex_lock(&g_mutex);
        for (int i = 0; i < g_sse_count; ) {
            if (FD_ISSET(g_sse_fds[i], &rfds)) {
                char tmp[8];
                ssize_t r = recv(g_sse_fds[i], tmp, sizeof(tmp), MSG_DONTWAIT);
                if (r <= 0) {
                    sock_close(g_sse_fds[i]);
                    g_sse_fds[i] = g_sse_fds[--g_sse_count];
                    continue;
                }
            }
            i++;
        }
        pthread_mutex_unlock(&g_mutex);
    }
    return NULL;
}
#else
static DWORD WINAPI server_thread_func(LPVOID arg) {
    (void)arg;
    while (g_running) {
        /* Windows: use select with 200ms timeout */
        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(g_listen_fd, &rfds);

        WaitForSingleObject(g_mutex, INFINITE);
        for (int i = 0; i < g_sse_count; i++) FD_SET(g_sse_fds[i], &rfds);
        ReleaseMutex(g_mutex);

        struct timeval tv = {0, 200000};
        int ret = select(0, &rfds, NULL, NULL, &tv);
        if (ret <= 0) {
            if (WaitForSingleObject(g_ctrl_event, 0) == WAIT_OBJECT_0) break;
            continue;
        }

        if (WaitForSingleObject(g_ctrl_event, 0) == WAIT_OBJECT_0) break;

        if (FD_ISSET(g_listen_fd, &rfds)) {
            sock_t cfd = accept(g_listen_fd, NULL, NULL);
            if (cfd != INVALID_SOCK) handle_connection(cfd);
        }

        WaitForSingleObject(g_mutex, INFINITE);
        for (int i = 0; i < g_sse_count; ) {
            if (FD_ISSET(g_sse_fds[i], &rfds)) {
                char tmp[8];
                int r = recv(g_sse_fds[i], tmp, sizeof(tmp), 0);
                if (r <= 0) {
                    closesocket(g_sse_fds[i]);
                    g_sse_fds[i] = g_sse_fds[--g_sse_count];
                    continue;
                }
            }
            i++;
        }
        ReleaseMutex(g_mutex);
    }
    return 0;
}
#endif

/* ── public API ────────────────────────────────────────────────────────────── */

/* Returns 1 on success, 0 on failure. */
int lattice_serve_start(int port, const char *root) {
    if (g_running) return 0; /* already running */
    if (!root || strlen(root) >= PATH_MAX_SIZE) return 0;
    strncpy(g_root, root, PATH_MAX_SIZE - 1);
    g_root[PATH_MAX_SIZE - 1] = '\0';

    /* strip trailing slash */
    size_t rlen = strlen(g_root);
    while (rlen > 0 && (g_root[rlen-1] == '/' || g_root[rlen-1] == '\\')) {
        g_root[--rlen] = '\0';
    }

#ifdef _WIN32
    WSADATA wsa;
    WSAStartup(MAKEWORD(2,2), &wsa);
    g_mutex = CreateMutex(NULL, FALSE, NULL);
    g_ctrl_event = CreateEvent(NULL, FALSE, FALSE, NULL);
#endif

    g_listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (g_listen_fd == INVALID_SOCK) return 0;

    int one = 1;
    setsockopt((int)g_listen_fd, SOL_SOCKET, SO_REUSEADDR,
               (const char *)&one, sizeof(one));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons((uint16_t)port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(g_listen_fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        sock_close(g_listen_fd);
        g_listen_fd = INVALID_SOCK;
        return 0;
    }
    if (listen(g_listen_fd, 16) != 0) {
        sock_close(g_listen_fd);
        g_listen_fd = INVALID_SOCK;
        return 0;
    }

#ifndef _WIN32
    if (pipe(g_ctrl) != 0) {
        sock_close(g_listen_fd);
        g_listen_fd = INVALID_SOCK;
        return 0;
    }
#endif

    g_sse_count = 0;
    g_running   = 1;

#ifndef _WIN32
    if (pthread_create(&g_thread, NULL, server_thread_func, NULL) != 0) {
        g_running = 0;
        sock_close(g_listen_fd);
        g_listen_fd = INVALID_SOCK;
        close(g_ctrl[0]); close(g_ctrl[1]);
        return 0;
    }
#else
    g_thread = CreateThread(NULL, 0, server_thread_func, NULL, 0, NULL);
    if (!g_thread) {
        g_running = 0;
        sock_close(g_listen_fd);
        g_listen_fd = INVALID_SOCK;
        return 0;
    }
#endif
    return 1;
}

/* Send SSE reload event to all connected clients. */
void lattice_serve_broadcast_reload(void) {
#ifndef _WIN32
    pthread_mutex_lock(&g_mutex);
    for (int i = 0; i < g_sse_count; ) {
        ssize_t n = sock_write(g_sse_fds[i], RELOAD_EVENT, strlen(RELOAD_EVENT));
        if (n <= 0) {
            sock_close(g_sse_fds[i]);
            g_sse_fds[i] = g_sse_fds[--g_sse_count];
        } else {
            i++;
        }
    }
    pthread_mutex_unlock(&g_mutex);
#else
    WaitForSingleObject(g_mutex, INFINITE);
    for (int i = 0; i < g_sse_count; ) {
        int n = send(g_sse_fds[i], RELOAD_EVENT, (int)strlen(RELOAD_EVENT), 0);
        if (n <= 0) {
            closesocket(g_sse_fds[i]);
            g_sse_fds[i] = g_sse_fds[--g_sse_count];
        } else {
            i++;
        }
    }
    ReleaseMutex(g_mutex);
#endif
}

/* Stop the server and release resources. */
void lattice_serve_stop(void) {
    if (!g_running) return;
    g_running = 0;
#ifndef _WIN32
    /* wake the select() in server_thread_func */
    char b = 1;
    (void)write(g_ctrl[1], &b, 1);
    pthread_join(g_thread, NULL);
    close(g_ctrl[0]); g_ctrl[0] = -1;
    close(g_ctrl[1]); g_ctrl[1] = -1;
    pthread_mutex_lock(&g_mutex);
    for (int i = 0; i < g_sse_count; i++) sock_close(g_sse_fds[i]);
    g_sse_count = 0;
    pthread_mutex_unlock(&g_mutex);
    sock_close(g_listen_fd);
    g_listen_fd = INVALID_SOCK;
#else
    SetEvent(g_ctrl_event);
    WaitForSingleObject(g_thread, 5000);
    CloseHandle(g_thread); g_thread = NULL;
    WaitForSingleObject(g_mutex, INFINITE);
    for (int i = 0; i < g_sse_count; i++) closesocket(g_sse_fds[i]);
    g_sse_count = 0;
    ReleaseMutex(g_mutex);
    closesocket(g_listen_fd); g_listen_fd = INVALID_SOCK;
    CloseHandle(g_mutex);
    CloseHandle(g_ctrl_event);
    WSACleanup();
#endif
}

/* Returns 1 if server is currently running. */
int lattice_serve_is_running(void) {
    return g_running;
}
