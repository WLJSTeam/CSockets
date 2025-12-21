#undef UNICODE

#define _DEBUG 1
#define FD_SETSIZE 4096
#define SECOND 1000000
#define MININTERVAL 1000

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
    extern Mutex globalMutex = NULL;
    #define MUTEX_INITIALIZER NULL
    #define SLEEP Sleep
    #define ms 1
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
    extern Mutex globalMutex;
    #define MUTEX_INITIALIZER PTHREAD_MUTEX_INITIALIZER
    #define SLEEP usleep
#endif

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stddef.h>
#include <time.h>

#include "WolframLibrary.h"
#include "WolframIOLibraryFunctions.h"
#include "WolframNumericArrayLibrary.h"
#include "WolframCompileLibrary.h"
#include "WolframRawArrayLibrary.h"
#include "WolframImageLibrary.h"

typedef struct SocketList_st *SocketList;

typedef struct Server_st *Server;

extern char* getCurrentTime();

extern void initGlobalMutex();

extern void closeGlobalMutex();

extern void lockGlobalMutex();

extern void unlockGlobalMutex();

extern void initWSA();

extern void cleanupWSA();

extern const int setBlockingMode(SOCKET socketId, bool blockingMode);

extern const bool blockingModeQ(SOCKET socketId);

extern void acceptErrorMessage(WolframLibraryData libData, int err);

extern void recvErrorMessage(WolframLibraryData libData, int err);

extern void selectErrorMessage(WolframLibraryData libData, int err);

extern void sendErrorMessage(WolframLibraryData libData, int err);

extern void pushSelect(WolframLibraryData libData, mint taskId, SOCKET *sockets, size_t socketsLength, fd_set *readset);

extern void pushAccept(WolframLibraryData libData, mint taskId, SOCKET listenSocket, SOCKET acceptedSocket);

extern void pushRecv(WolframLibraryData libData, mint taskId, SOCKET listenSocket, SOCKET socketId, BYTE *buffer, int bufferLength);

extern void pushRecvFrom(WolframLibraryData libData, mint taskId, SOCKET socketId, struct sockaddr *address, BYTE *buffer, int bufferLength);

extern void pushClose(WolframLibraryData libData, mint taskId, SOCKET socketId);