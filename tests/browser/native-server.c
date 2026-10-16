/* Use the real backend and discover its OS-assigned loopback port. */
#include "../../src/serve/serve_native.c"

int main(int argc, char **argv) {
    if (argc != 2 || !lattice_serve_start(0, argv[1])) return 1;
    struct sockaddr_in address;
    socklen_t size = sizeof(address);
    if (getsockname(g_listen_fd, (struct sockaddr *)&address, &size) != 0) {
        lattice_serve_stop();
        return 2;
    }
    printf("%u\n", (unsigned)ntohs(address.sin_port));
    fflush(stdout);
    (void)getchar();
    lattice_serve_stop();
    return 0;
}
