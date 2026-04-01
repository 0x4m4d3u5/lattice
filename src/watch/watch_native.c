#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <time.h>
#include <sys/stat.h>

#if defined(_WIN32)
#include <windows.h>
#endif

static volatile sig_atomic_t lattice_watch_interrupted_flag = 0;

static void lattice_watch_sigint_handler(int signo) {
  (void)signo;
  lattice_watch_interrupted_flag = 1;
}

int64_t lattice_watch_mtime_millis(const char *path) {
  struct stat st;
  if (stat(path, &st) != 0) {
    return -1;
  }
#if defined(__APPLE__)
  return ((int64_t)st.st_mtimespec.tv_sec * 1000) +
         (st.st_mtimespec.tv_nsec / 1000000);
#elif defined(_WIN32)
  return ((int64_t)st.st_mtime) * 1000;
#else
  return ((int64_t)st.st_mtim.tv_sec * 1000) + (st.st_mtim.tv_nsec / 1000000);
#endif
}

void lattice_watch_sleep_ms(int ms) {
  if (ms <= 0) {
    return;
  }
#if defined(_WIN32)
  Sleep((DWORD)ms);
#else
  struct timespec req;
  req.tv_sec = ms / 1000;
  req.tv_nsec = (long)(ms % 1000) * 1000000L;
  while (nanosleep(&req, &req) != 0 && errno == EINTR) {
  }
#endif
}

void lattice_watch_install_sigint_handler(void) {
  signal(SIGINT, lattice_watch_sigint_handler);
}

int lattice_watch_interrupted(void) {
  return lattice_watch_interrupted_flag != 0;
}

void lattice_watch_clear_interrupt(void) {
  lattice_watch_interrupted_flag = 0;
}

int64_t lattice_watch_current_unix_second(void) {
  return (int64_t)time(NULL);
}

int64_t lattice_watch_current_millis(void) {
#if defined(_WIN32)
  FILETIME ft;
  GetSystemTimeAsFileTime(&ft);
  uint64_t t = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
  return (int64_t)((t - 116444736000000000ULL) / 10000ULL);
#else
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
#endif
}
