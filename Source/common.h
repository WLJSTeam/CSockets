#ifndef COMMON_H
#define COMMON_H


#undef UNICODE


#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #define ISVALIDSOCKET(s) ((s) != INVALID_SOCKET)
    #define CLOSESOCKET(s) closesocket(s)
    #define GETSOCKETERRNO() (WSAGetLastError())
    #pragma comment (lib, "Ws2_32.lib")
    #define POLL_FD WSAPOLLFD
#else
    #include <sys/types.h>
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <netdb.h>
    #include <unistd.h>
    #include <errno.h>
    #include <fcntl.h>
    #include <wchar.h>
    #include <netinet/tcp.h>
    #include <sys/select.h>
    #include <pthread.h>
    #include <dlfcn.h>
    #define INVALID_SOCKET -1
    #define SOCKET_ERROR -1
    #define ZeroMemory(Destination,Length) memset((Destination),0,(Length))
    #define SOCKET int
    #define ISVALIDSOCKET(s) ((s) >= 0)
    #define CLOSESOCKET(s) close(s)
    #define GETSOCKETERRNO() (errno)
    #define BYTE uint8_t
    #include <poll.h>
    #define POLL_FD struct pollfd
#endif


#define WL_POLLIN   0x0001   // 1  - ready to read
#define WL_POLLOUT  0x0002   // 2  - ready to write
#define WL_POLLERR  0x0004   // 4  - error
#define WL_POLLHUP  0x0008   // 8  - socket closed
#define WL_POLLNVAL 0x0010   // 16 - invalid socket


#include <limits.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdarg.h>


#include "WolframLibrary.h"
#include "WolframIOLibraryFunctions.h"
#include "WolframNumericArrayLibrary.h"
#include "WolframCompileLibrary.h"
#include "WolframRawArrayLibrary.h"
#include "WolframImageLibrary.h"


/* Returns a new UBit8 vector containing a copy, or NULL on failure. */
MNumericArray MNumericArrayFromByte(WolframLibraryData libData, const BYTE *bytes, size_t length);


/* Borrowed bytes, not owned by caller; length is set to zero for invalid arrays. */
BYTE *ByteFromMNumericArray(WolframLibraryData libData, MNumericArray array, size_t *length);


/* New integer vector, or NULL on failure. */
MTensor MTensorFromSocket(WolframLibraryData libData, const SOCKET *sockets, size_t length);


/* New native descriptor buffer (also for empty input); caller frees it. */
SOCKET *SocketFromMTensor(WolframLibraryData libData, MTensor tensor, size_t *length);


char *format(const char *fmt, ...);


void init_wsa();


void cleanup_wsa();


typedef enum SOCKET_ROLE {
    SOCKET_ROLE_TCP_UNSPEC = 0,
    SOCKET_ROLE_TCP_BOUND = 1,
    SOCKET_ROLE_TCP_CONNECTED = 2,
    SOCKET_ROLE_TCP_ACCEPTED = 3,
    SOCKET_ROLE_UDP_UNSPEC = 4,
    SOCKET_ROLE_UDP_BOUND = 5,
    SOCKET_ROLE_UDP_CONNECTED = 6
} SOCKET_ROLE;


typedef struct socket_list {
    SOCKET *sockets;
    SOCKET_ROLE *roles;
    size_t capacity;
    size_t length;
} socket_list;


/* Copies the initial descriptors and roles; returns NULL on allocation failure. */
socket_list *create_socket_list(const mint *socketIds, const mint *roles, size_t length);


/* Frees list storage without closing its sockets. */
void remove_socket_list(socket_list *list);


bool socket_list_add(socket_list *list, SOCKET socketId, SOCKET_ROLE role);


bool socket_list_prune(socket_list *list);


/* length is the allocated element count; events contains native poll flags.
   On allocation failure, fds and length retain their previous values. */
bool socket_list_to_poll_fd(socket_list *list, POLL_FD **fds, size_t *length, int events);


int set_blocking_mode(SOCKET socketId);


int set_nonblocking_mode(SOCKET socketId);


struct sockaddr_storage create_sockaddr_storage(const char *numerichost, const char *port);


char *sockaddr_storage_to_string(struct sockaddr_storage address);


bool is_would_block_err(int err);


bool is_connect_pending_err(int err);


int sockets_poll(POLL_FD *fds, mint length, mint timeout_us);


int sockets_poll_abort(WolframLibraryData libData, POLL_FD *fds, mint length, mint timeout_us, mint slice_limit);


int convert_wl_to_native_events(mint wl_events);


mint convert_native_to_wl_events(int native_revents);


int socket_address_to_host(const struct sockaddr_storage *address, char *host, size_t hostLength, unsigned short *port);


#endif
