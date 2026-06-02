#ifndef COMMON_H
#define COMMON_H


#undef UNICODE


#define _DEBUG 1
#define FD_SETSIZE 4096
#define SECOND 1000000
#define MININTERVAL 1000
#define USEC_PER_SEC 1000000L


#define BLOCKING_MODE 0
#define NON_BLOCKING_MODE 1


#define RESET "\033[0m"
#define RED "\033[91m"
#define GREEN "\033[92m"
#define BLUE "\033[94m"
#define YELLOW "\033[93m"


#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #define ISVALIDSOCKET(s) ((s) != INVALID_SOCKET)
    #define CLOSESOCKET(s) closesocket(s)
    #define GETSOCKETERRNO() (WSAGetLastError())
    #pragma comment (lib, "Ws2_32.lib")
    typedef HANDLE Mutex;
    extern Mutex globalMutex;
    #define MUTEX_INITIALIZER NULL
    #define SLEEP Sleep
    #define ms 1
    #define POLL_FD WSAPOLLFD
    #define POLL_FUNCTION WSAPoll
    #define POLLIN_FLAG POLLRDNORM
    #define POLLERR_FLAG POLLERR
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
    #include <time.h>
    #include <sys/time.h>
    #include <pthread.h>
    #include <dlfcn.h>
    #define INVALID_SOCKET -1
    #define NO_ERROR 0
    #define SOCKET_ERROR -1
    #define ZeroMemory(Destination,Length) memset((Destination),0,(Length))
    inline void nopp() {}
    #define SOCKET int
    #define ISVALIDSOCKET(s) ((s) >= 0)
    #define CLOSESOCKET(s) close(s)
    #define GETSOCKETERRNO() (errno)
    #define BYTE uint8_t
    #define BOOL int
    typedef pthread_mutex_t Mutex;
    #define MUTEX_INITIALIZER PTHREAD_MUTEX_INITIALIZER
    extern Mutex globalMutex;
    #define SLEEP usleep
    #include <poll.h>
    #define POLL_FD struct pollfd
    #define POLL_FUNCTION poll
    #define POLLIN_FLAG POLLIN
    #define POLLERR_FLAG POLLERR
#endif


#define WL_POLLIN   0x0001   // 1  - ready to read
#define WL_POLLOUT  0x0002   // 2  - ready to write
#define WL_POLLERR  0x0004   // 4  - error
#define WL_POLLHUP  0x0008   // 8  - socket closed
#define WL_POLLNVAL 0x0010   // 16 - invalid socket


#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stddef.h>
#include <time.h>
#include <stdarg.h>


#include "WolframLibrary.h"
#include "WolframIOLibraryFunctions.h"
#include "WolframNumericArrayLibrary.h"
#include "WolframCompileLibrary.h"
#include "WolframRawArrayLibrary.h"
#include "WolframImageLibrary.h"


void print(const char* format, ...);


char* get_current_time();


void init_wsa();


void cleanup_wsa();


void set_blocking_mode(SOCKET socketId);


void set_non_blocking_mode(SOCKET socketId);


bool is_non_blocking_mode(SOCKET socketId);


bool is_valid_socket(SOCKET socketId);


struct timeval new_tv(long long usec);


size_t filter_fd_set_to_array(fd_set *set, SOCKET *input, SOCKET *result, size_t length);


size_t filter_fd_set_to_tensor(WolframLibraryData libData, fd_set *set, SOCKET *input, MTensor result, size_t length);


SOCKET fill_fd_set_from_array(fd_set *set, SOCKET *sockets, size_t length, SOCKET initmaxfd);


void copy_tensor_to_socket_array(WolframLibraryData libData, MTensor tensor, SOCKET *result, size_t length);


int sockets_poll(POLL_FD *fds, mint length, mint timeout_us);


int convert_wl_to_native_events(mint wl_events);


mint convert_native_to_wl_events(int native_revents);


#endif