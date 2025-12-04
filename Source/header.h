#pragma region header.h

#undef UNICODE

#define FD_SETSIZE 4096
#define SECOND 1000000
#define MININTERVAL 1000
#define _DEBUG 1
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
    #define SLEEP usleep
    #define ms 1000
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

// Platform-specific global mutex:
#if defined(_WIN32) || defined(_WIN64)
static Mutex globalMutex = NULL;
#else
static Mutex globalMutex = PTHREAD_MUTEX_INITIALIZER;
#endif

#pragma endregion

#pragma region utils.c

const char* getCurrentTime();

Mutex mutexCreate();

void mutexClose(Mutex mutex);

void mutexLock(Mutex mutex);

void mutexUnlock(Mutex mutex);

#pragma endregion

#pragma region structures

typedef struct SocketList_st *SocketList;

typedef struct Server_st *Server;

struct SocketList_st
{
    SOCKET interrupt; // interrupts waiting from WL session
    SOCKET *sockets;
    size_t length;
    mint timeout;
    WolframLibraryData libData;
};

struct Server_st
{
    SOCKET interrupt;
    SOCKET listenSocket;
    size_t clientsCapacity;
    size_t bufferSize;
    long timeout;
    SOCKET *clients;
    fd_set clientsReadSet;
    size_t clientsReadSetLength;
    size_t clientsLength;
    BYTE *buffer;
    WolframLibraryData libData;
    mint taskId;
};

DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListSet(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int serverCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int serverRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketAddressInfoCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketAddressInfoRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

#pragma endregion

#pragma region blocking

const void setBlocking(SOCKET socket, bool blocking);

const bool blockingModeQ(SOCKET socketId);

#pragma endregion

#pragma library link ritual

DLLEXPORT mint WolframLibrary_getVersion()
{
    #ifdef _DEBUG
    printf("%s\n%sWolframLibrary_getVersion[]%s -> %s%d%s\n\n", 
        getCurrentTime(),
        BLUE, RESET, 
        GREEN, WolframLibraryVersion, RESET
    );
    #endif

    return WolframLibraryVersion;
}

DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData)
{
    #ifdef _WIN32
    int iResult;
    WSADATA wsaData;

    iResult = WSAStartup(MAKEWORD(2,2), &wsaData);
    if (iResult != 0) return LIBRARY_FUNCTION_ERROR;
    #endif

    globalMutex = mutexCreate();

    #ifdef _DEBUG
    printf("%s\n%sWolframLibrary_initialize[]%s -> %sSuccess%s\n\n", 
        getCurrentTime(),
        BLUE, RESET, GREEN, RESET
    );
    #endif

    return LIBRARY_NO_ERROR;
}

DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData)
{
    #ifdef _WIN32
    WSACleanup();
    #else
    sleep(1);
    #endif

    #ifdef _DEBUG
    printf("%s\n%sWolframLibrary_uninitialize[]%s -> %sSuccess%s\n\n",
        getCurrentTime(),
        BLUE, RESET, GREEN, RESET
    );
    #endif

    #if defined(_WIN32) || defined(_WIN64)
        CloseHandle(globalMutex);
    #else
        pthread_mutex_destroy(&globalMutex);
    #endif

    return;
}

#pragma endregion