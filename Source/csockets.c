#pragma region header

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

typedef struct SocketList_st *SocketList;

typedef struct Server_st *Server;

#pragma endregion

/*
    TIME
*/

const char* getCurrentTime()
{
    static char time_buffer[64];
    time_t rawtime;
    struct tm* timeinfo;
    
    time(&rawtime);
    timeinfo = localtime(&rawtime);
    
    strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%d %H:%M:%S", timeinfo);
    
    #ifdef _WIN32
    SYSTEMTIME st;
    GetSystemTime(&st);
    snprintf(time_buffer + strlen(time_buffer), 
             sizeof(time_buffer) - strlen(time_buffer), 
             ".%03d", st.wMilliseconds);
    #else
    struct timeval tv;
    gettimeofday(&tv, NULL);
    snprintf(time_buffer + strlen(time_buffer), 
             sizeof(time_buffer) - strlen(time_buffer), 
             ".%06ld", tv.tv_usec);
    #endif
    
    return time_buffer;
}

/*
    MUTEX
*/

Mutex mutexCreate()
{
    #if defined(_WIN32) || defined(_WIN64)
        return CreateMutex(NULL, FALSE, NULL);
    #else
        pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
        return mutex;
    #endif
}

void mutexClose(Mutex mutex)
{
    #if defined(_WIN32) || defined(_WIN64)
        CloseHandle(mutex);
    #else
        pthread_mutex_destroy(&mutex);
    #endif
}

void mutexLock(Mutex mutex)
{
    #if defined(_WIN32) || defined(_WIN64)
        WaitForSingleObject(mutex, INFINITE);
    #else
        pthread_mutex_lock(&mutex);
    #endif
}

void mutexUnlock(Mutex mutex)
{
    #if defined(_WIN32) || defined(_WIN64)
        ReleaseMutex(mutex);
    #else
        pthread_mutex_unlock(&mutex);
    #endif
}

/*
    RITUAL
*/

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

    mutexClose(globalMutex);

    return;
}

/*
    BLOCKING
*/

const void setBlocking(SOCKET socket, bool blocking)
{
    #ifdef _WIN32
    u_long mode = blocking ? 0 : 1; // 0 for blocking, 1 for non-blocking
    ioctlsocket(socket, FIONBIO, &mode);
    #else
    int flags = fcntl(socket, F_GETFL, 0);
    if (blocking) {
        fcntl(socket, F_SETFL, flags & ~O_NONBLOCK);
    } else {
        fcntl(socket, F_SETFL, flags | O_NONBLOCK);
    }
    #endif
}

const bool blockingModeQ(SOCKET socketId)
{
    #ifdef _WIN32
    u_long mode;
    ioctlsocket(socketId, FIONBIO, &mode);
    return (mode == 0);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    return !(flags & O_NONBLOCK);
    #endif
}

/*
    STRUCTS
*/

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

/*
    CONSTRUCTORS
*/

/*socketListCreate[interrupt, length] -> socketListPtr*/
DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET interrupt = (SOCKET)MArgument_getInteger(Args[0]);
    SOCKET length = (size_t)MArgument_getInteger(Args[1]);

    SocketList socketList = malloc(sizeof(struct SocketList_st));

    socketList->interrupt = interrupt;
    socketList->length = length; 
    socketList->sockets = malloc(length * sizeof(SOCKET));
    socketList->libData = libData;

    #ifdef _DEBUG
    printf("%s\n%ssocketListCreate[%s%I64d, size = %d%s]%s -> %s<%p>%s\n\n", 
        getCurrentTime(), 
        BLUE, RESET, 
        interrupt, length,
        BLUE, RESET, 
        GREEN, (void *)socketList, RESET
    );
    #endif

    uint64_t socketsPtr = (uint64_t)(uintptr_t)socketList;
    MArgument_setInteger(Res, (mint)socketsPtr);

    return LIBRARY_NO_ERROR; 
}

/*socketsSet[socketListPtr, {sockets}, length] -> successStatus*/
DLLEXPORT int socketListSet(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    MTensor socketsTensor = MArgument_getMTensor(Args[1]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[2]); // length of the list
    SOCKET *sockets = (SOCKET*)libData->MTensor_getIntegerData(socketsTensor);

    if (length > socketList->length){
        socketList->sockets = realloc(socketList->sockets, length * sizeof(SOCKET));
    }

    memcpy(socketList->sockets, sockets, length * sizeof(SOCKET));
    socketList->length = length;

    #ifdef _DEBUG
    printf("%s\n%ssocketListSet[]%s -> %sSuccess%s\n\n", 
        getCurrentTime(), 
        BLUE, RESET, 
        GREEN, RESET
    );
    #endif

    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR;
}

/*socketsRemove[socketListPtr] -> successState*/
DLLEXPORT int socketListRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);

    CLOSESOCKET(socketList->interrupt);

    for (size_t i = 0; i < socketList->length; i++) {
        if (ISVALIDSOCKET(socketList->sockets[i])) {
            CLOSESOCKET(socketList->sockets[i]);
        }
    }

    free(socketList->sockets);
    free(socketList);

    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR; 
}

/*serverCreate[interrupt, listenSocket, clientsCapacity, bufferSize] -> serverPtr*/
DLLEXPORT int serverCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET interrupt =       (SOCKET)MArgument_getInteger(Args[0]); // positive integer
    SOCKET listenSocket =    (SOCKET)MArgument_getInteger(Args[1]); // positive integer
    size_t clientsCapacity = (size_t)MArgument_getInteger(Args[2]); // 1024 by default
    size_t bufferSize =      (size_t)MArgument_getInteger(Args[3]); // 64 kB by default
    long timeout =           (long)MArgument_getInteger(Args[4]);   // 1 s by default

    #ifdef _DEBUG
    printf("%s\n%sserverCreate[]%s -> ", 
        getCurrentTime(),
        BLUE, RESET
    );
    #endif

    void *ptr = malloc(sizeof(struct Server_st));
    if (!ptr) {
        #ifdef _DEBUG
        printf("%smalloc ERROR%s\n\n", 
            RED, RESET
        );
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    Server server = (Server)ptr;

    server->interrupt = interrupt;
    server->listenSocket = listenSocket;
    server->clientsCapacity = clientsCapacity;
    server->clientsLength = 0;
    server->clientsReadSetLength = 0;
    server->bufferSize = bufferSize;
    server->timeout = timeout;
    server->libData = libData;

    server->clients = malloc(clientsCapacity * sizeof(SOCKET));
    if (!server->clients){
        #ifdef _DEBUG
        printf("%smalloc for clients ERROR%s\n\n", 
            RED, RESET
        );
        #endif

        free(ptr);
        return LIBRARY_FUNCTION_ERROR;
    }

    server->buffer = (char*)malloc(bufferSize * sizeof(char));
    if (!server->buffer){
        #ifdef _DEBUG
        printf("%smalloc for buffer ERROR%s\n\n", 
            RED, RESET
        );
        #endif

        free(server->clients);
        free(ptr);
        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%s<%p>%s\n\n",
        GREEN, ptr, RESET
    );
    #endif

    uint64_t serverPtr = (uint64_t)(uintptr_t)ptr;
    MArgument_setInteger(Res, serverPtr);
    return LIBRARY_NO_ERROR;
}

/*serverRemove[serverPtr] -> successState*/
DLLEXPORT int serverRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    Server server = (Server)MArgument_getInteger(Args[0]); 

    CLOSESOCKET(server->interrupt);
    CLOSESOCKET(server->listenSocket);

    for (size_t i = 0; i < server->clientsLength; i++) {
        if (ISVALIDSOCKET(server->clients[i])) {
            CLOSESOCKET(server->clients[i]);
        }
    }

    free(server->clients);
    free(server->buffer);
    free(server);

    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*socketAddressInfoCreate["host", "port", family, socktype, protocol] -> addressInfoPtr*/
DLLEXPORT int socketAddressInfoCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    char *host = MArgument_getUTF8String(Args[0]); // localhost by default
    char *port = MArgument_getUTF8String(Args[1]); // positive integer as string

    int ai_family = (int)MArgument_getInteger(Args[2]); // AF_UNSPEC == 0 | AF_INET == 2 | AF_INET6 == 23/10 | ..
    int ai_socktype = (int)MArgument_getInteger(Args[3]); // SOCK_STREAM == 1 | SOCK_DGRAM == 2 | SOCK_RAW == 3 | ..
    int ai_protocol = (int)MArgument_getInteger(Args[4]); // 0 | IPPROTO_TCP == 6 | IPPROTO_UDP == 17 | IPPROTO_SCTP == 132 | IPPROTO_ICMP == 1 | ..

    #ifdef _DEBUG
    printf("%s\n%socketAddressInfoCreate[%s%s:%s, family = %d, socktype = %d, protocol = %d%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        host, port, ai_family, ai_socktype, ai_protocol, 
        BLUE, RESET
    );
    #endif

    int result;
    struct addrinfo *address = NULL;
    struct addrinfo hints;

    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = ai_family;
    hints.ai_socktype = ai_socktype;
    hints.ai_protocol = ai_protocol;

    result = getaddrinfo(host, port, &hints, &address);
    if (result != 0){
        #ifdef _DEBUG
        printf("%sERROR%s\n\n", 
            RED, RESET
        );
        #endif

        libData->UTF8String_disown(host);
        libData->UTF8String_disown(port);
        return LIBRARY_FUNCTION_ERROR;
    }

    libData->UTF8String_disown(host);
    libData->UTF8String_disown(port);

    uintptr_t addressPtr = (uintptr_t)address;

    #ifdef _DEBUG
    printf("%s<%p>%s\n\n", 
        GREEN, (void*)addressPtr, RESET
    );
    #endif

    MArgument_setInteger(Res, (mint)addressPtr);
    return LIBRARY_NO_ERROR;
}

/*socketAddressInfoRemove[addressPtr] -> successStatus*/
DLLEXPORT int socketAddressInfoRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[0]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    #ifdef _DEBUG
    printf("%s\n%socketAddressInfoRemove[%s<%p>%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        (void*)addressPtr, 
        BLUE, RESET
    );
    #endif

    if (address == NULL) {
        #ifdef _DEBUG
        printf("%sERROR%s\n\n", 
            RED, RESET
        );
        #endif

        MArgument_setInteger(Res, 1); // failure
        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%sSuccess%s\n\n", 
        GREEN, RESET
    );
    #endif

    freeaddrinfo(address);
    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR;
}

/*socketAddressCreate[addressType] -> addressPtr*/
DLLEXPORT int socketAddressCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    struct sockaddr_in *address = malloc(sizeof(struct sockaddr_in));
    if (address == NULL) {
        return LIBRARY_FUNCTION_ERROR;
    }

    uintptr_t ptr = (uintptr_t)address;
    MArgument_setInteger(Res, (mint)ptr);
    return LIBRARY_NO_ERROR;
}

/*socketAddressRemove[addressPtr] -> successStatus*/
DLLEXPORT int socketAddressRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    uintptr_t ptr = (uintptr_t)MArgument_getInteger(Args[0]);
    struct sockaddr_in *address = (struct sockaddr_in *)ptr;

    free(address);
    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*socketBufferCreate[bufferSize] -> bufferPtr*/
DLLEXPORT int socketBufferCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    mint bufferSize = (mint)MArgument_getInteger(Args[0]);
    BYTE *buffer = malloc(bufferSize * sizeof(BYTE));
    uintptr_t bufferPtr = (uintptr_t)buffer;
    MArgument_setInteger(Res, bufferPtr);
    return LIBRARY_NO_ERROR;
}

/*socketBufferRemove[bufferPtr] -> successStatus*/
DLLEXPORT int socketBufferRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    BYTE * buffer = (BYTE *)MArgument_getInteger(Args[0]);
    free(buffer);
    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*
    ERROR MESSAGES
*/

void acceptErrorMessage(WolframLibraryData libData, int err)
{
    #ifdef _WIN32
    if (err == WSAEINTR)
    #else
    if (err == EINTR)
    #endif
        libData->Message("acceptRetry");

    #ifdef _WIN32
    else if (err == WSAEWOULDBLOCK)
    #else
    else if (err == EAGAIN || err == EWOULDBLOCK)
    #endif
        libData->Message("acceptDelayRetry");

    #ifdef _WIN32
    else if (err == WSAEMFILE || err == WSAENOBUFS || err == WSAENETDOWN || err == WSAEINVAL)
    #else
    else if (err == EMFILE || err == ENFILE || err == ENOBUFS || err == ENOMEM || err == EOPNOTSUPP)
    #endif
        libData->Message("acceptCloseSocket");

    #ifdef _WIN32
    else if (err == WSAENOTSOCK || err == WSAEINVAL || err == WSAEFAULT)
    #else
    else if (err == EBADF || err == EINVAL || err == EFAULT)
    #endif
        libData->Message("acceptFixParams");

    #ifdef _WIN32
    else if (err == WSAEINVALIDPROVIDER || err == WSAEPROVIDERFAILEDINIT || err == WSASYSCALLFAILURE)
        libData->Message("acceptReinitWinsock");
    #endif

    #ifndef _WIN32
    else if (err == ENOBUFS || err == ENOMEM || err == ENETDOWN
            || err == ENETUNREACH || err == ENETRESET
            || err == EAFNOSUPPORT || err == EPROTONOSUPPORT
            || err == ESOCKTNOSUPPORT)
        libData->Message("acceptRestartProcess");
    #endif

    else
        libData->Message("acceptUnexpectedError");
}

void recvErrorMessage(WolframLibraryData libData, int err)
{
    if (err == 0) {
        libData->Message("recvGracefulClose");
        return;
    }

    #ifdef _WIN32
    if (err == WSAEINTR)
    #else
    if (err == EINTR)
    #endif
        libData->Message("recvRetry");

    #ifdef _WIN32
    else if (err == WSAEWOULDBLOCK)
    #else
    else if (err == EAGAIN || err == EWOULDBLOCK)
    #endif
        libData->Message("recvDelayRetry");

    #ifdef _WIN32
    else if (err == WSAECONNRESET || err == WSAECONNABORTED || err == WSAESHUTDOWN || err == WSAENOTCONN)
    #else
    else if (err == ECONNRESET || err == ECONNABORTED || err == ESHUTDOWN || err == ENOTCONN)
    #endif
        libData->Message("recvCloseSocket");

    #ifdef _WIN32
    else if (err == WSAENOTSOCK || err == WSAEINVAL || err == WSAEFAULT)
    #else
    else if (err == EBADF || err == EINVAL || err == EFAULT)
    #endif
        libData->Message("recvFixParams");

    #ifdef _WIN32
    else if (err == WSAEINVALIDPROVIDER || err == WSAEPROVIDERFAILEDINIT || err == WSASYSCALLFAILURE)
        libData->Message("recvReinitWinsock");
    #endif

    #ifndef _WIN32
    else if (err == ENOBUFS || err == ENOMEM || err == ENETDOWN
            || err == ENETUNREACH || err == ENETRESET
            || err == EAFNOSUPPORT || err == EPROTONOSUPPORT
            || err == ESOCKTNOSUPPORT)
        libData->Message("recvRestartProcess");
    #endif

    else
        libData->Message("recvUnexpectedError");
}

void selectErrorMessage(WolframLibraryData libData, int err)
{
    #ifdef _WIN32
    if (err == WSAEINTR)
    #else
    if (err == EINTR)
    #endif
        libData->Message("selectRetry");

    #ifdef _WIN32
    else if (err == WSAENOTSOCK || err == WSAEFAULT || err == WSAEINVAL || err == WSAENOBUFS)
    #else
    else if (err == EBADF || err == EFAULT || err == EINVAL || err == ENOMEM)
    #endif
        libData->Message("selectClose");

    #ifdef _WIN32
    else if (err == WSAENOTSOCK || err == WSAEINVAL || err == WSAEFAULT)
    #else
    else if (err == EBADF || err == EINVAL || err == EFAULT)
    #endif
        libData->Message("selectFixParams");

    #ifdef _WIN32
    else if (err == WSAEINVALIDPROVIDER || err == WSAEPROVIDERFAILEDINIT || err == WSASYSCALLFAILURE)
        libData->Message("selectReinitWinsock");
    #endif

    #ifndef _WIN32
    else if (err == ENOBUFS || err == ENOMEM || err == ENETDOWN
            || err == ENETUNREACH || err == ENETRESET
            || err == EAFNOSUPPORT || err == EPROTONOSUPPORT
            || err == ESOCKTNOSUPPORT)
        libData->Message("selectRestartProcess");
    #endif

    else
        libData->Message("selectUnexpectedError");
}

void sendErrorMessage(WolframLibraryData libData, int err)
{
    #ifdef _WIN32
    if (err == WSAEINTR)
    #else
    if (err == EINTR)
    #endif
        libData->Message("sendRetry");

    #ifdef _WIN32
    else if (err == WSAEWOULDBLOCK)
    #else
    else if (err == EAGAIN || err == EWOULDBLOCK)
    #endif
        libData->Message("sendDelayRetry");

    #ifdef _WIN32
    else if (err == WSAENOTCONN || err == WSAESHUTDOWN || err == WSAECONNRESET)
    #else
    else if (err == ENOTCONN || err == EPIPE || err == ECONNRESET || err == ESHUTDOWN)
    #endif
        libData->Message("sendCloseSocket");

    #ifdef _WIN32
    else if (err == WSAEMSGSIZE)
    #else
    else if (err == EMSGSIZE)
    #endif
        libData->Message("sendMsgSize");

    #ifdef _WIN32
    else if (err == WSAENOTSOCK || err == WSAEINVAL || err == WSAEFAULT)
    #else
    else if (err == EBADF || err == EINVAL || err == EFAULT)
    #endif
        libData->Message("sendFixParams");

    #ifdef _WIN32
    else if (err == WSAEINVALIDPROVIDER || err == WSAEPROVIDERFAILEDINIT || err == WSASYSCALLFAILURE)
        libData->Message("sendReinitWinsock");
    #endif

    #ifndef _WIN32
    else if (err == ENOBUFS || err == ENOMEM || err == ENETDOWN
            || err == ENETUNREACH || err == ENETRESET
            || err == EAFNOSUPPORT || err == EPROTONOSUPPORT
            || err == ESOCKTNOSUPPORT)
        libData->Message("sendRestartProcess");
    #endif

    else
        libData->Message("sendUnexpectedError");
}

/*
    SOCKET FUNCTIONS
*/

/*socketCreate[family, socktype, protocol] -> socketId*/
DLLEXPORT int socketCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    int family = (int)MArgument_getInteger(Args[0]); // family
    int socktype = (int)MArgument_getInteger(Args[1]); // sock type
    int protocol = (int)MArgument_getInteger(Args[2]); // protocol

    #ifdef _DEBUG
    printf("%s\n%ssocketCreate[%s%I64d, %I64d, %I64d%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        family, socktype, protocol, 
        BLUE, RESET
    );
    #endif

    SOCKET createdSocket = socket(family, socktype, protocol);
    if (createdSocket == INVALID_SOCKET){
        #ifdef _DEBUG
        printf("%sERROR = %d%s\n\n", 
            getCurrentTime(), 
            RED, GETSOCKETERRNO(), RESET
        );
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%ssocketId = %I64d%s\n\n", 
        GREEN, createdSocket, RESET
    );
    #endif

    MArgument_setInteger(Res, createdSocket); // return socket id
    return LIBRARY_NO_ERROR;
}

/*socketCreate[socketId] -> successStatus*/
DLLEXPORT int socketClose(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = MArgument_getInteger(Args[0]); // positive integer

    #ifdef _DEBUG
    printf("%s\n%ssocketClose[%s%I64d%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        socketId, 
        BLUE, RESET
    );
    #endif

    mint result = true;

    if (socketId > 0) {
        mutexLock(globalMutex);
        result = CLOSESOCKET(socketId);
        mutexUnlock(globalMutex);
    }

    if (result == SOCKET_ERROR) {
        #ifdef _DEBUG
        printf("%sERROR = %d%s\n\n", 
            RED, GETSOCKETERRNO(), RESET
        );
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%sSuccess%s\n\n", 
        GREEN, RESET
    );
    #endif

    MArgument_setInteger(Res, result);
    return LIBRARY_NO_ERROR;
}

/*socketBind[socketId, addressPtr] -> successStatus*/
DLLEXPORT int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket for binding
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[1]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    bool successState = 0;

    #ifdef _DEBUG
    printf("%s\n%ssocketBind[%s%I64d, <%p>%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        socketId, (void*)address, 
        BLUE, RESET
    );
    #endif

    if (address == NULL) {
        #ifdef _DEBUG
        printf("%sERROR invalid address%s\n\n", 
            RED, RESET
        );
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    if (socketId == INVALID_SOCKET) {
        #ifdef _DEBUG
        printf("%sERROR invalid socket%s\n\n", 
            RED, RESET
        );
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    int iResult = bind(socketId, address->ai_addr, (int)address->ai_addrlen);
    if (iResult == SOCKET_ERROR) {
        #ifdef _DEBUG
        printf("%sERROR = %d\n\n", 
            RED, GETSOCKETERRNO(), RESET
        );
        #endif
        
        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%sSuccess%s\n\n", 
        GREEN, RESET
    );
    #endif

    MArgument_setInteger(Res, successState); // success = 0
    return LIBRARY_NO_ERROR;
}

/*socketSetOpt[socketId, level, optName, optVal] -> successStatus*/
DLLEXPORT int socketSetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);
    int optval = (int)MArgument_getInteger(Args[3]);

    #ifdef _DEBUG
    printf("%s\n%ssocketSetOpt[%s%I64d, %I64d, %I64d%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        socketId, level, optname, optval, 
        BLUE, RESET
    );
    #endif

    int iResult = setsockopt(socketId, level, optname, (const char*)&optval, sizeof(optval));
    if (iResult == SOCKET_ERROR) {
        #ifdef _DEBUG
        printf("%sERROR = %d%s\n\n", 
            RED, GETSOCKETERRNO(), RESET
        );
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%sSuccess%s\n\n", 
        GREEN, RESET
    );
    #endif

    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR;
}

/*socketGetOpt[socketId, level, optName] -> optVal*/
DLLEXPORT int socketGetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket id
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);

    int optval = 0;
    socklen_t optlen = sizeof(optval);

    #ifdef _DEBUG
    printf("%s\n%ssocketGetOpt[%s%I64d, %I64d, %I64d%s]%s -> ",
        getCurrentTime(),
        BLUE, RESET,
        socketId, level, optname,
        BLUE, RESET
    );
    #endif

    int iResult = getsockopt(socketId, level, optname, (char*)&optval, &optlen);
    if (iResult == SOCKET_ERROR) {
        #ifdef _DEBUG
        printf("%sERROR = %d%s\n\n",
            RED, GETSOCKETERRNO(), RESET
        );
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%sSuccess%s: %d\n\n",
        GREEN, RESET, optval
    );
    #endif

    MArgument_setInteger(Res, optval); // return retrieved value
    return LIBRARY_NO_ERROR;
}

/*socketBlockingMode[socketId, mode] -> successStatus*/
DLLEXPORT int socketBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket
    int nonBlocking = (int)MArgument_getInteger(Args[1]); // 0 | 1 default 0 == blocking mode
    
    #ifdef _DEBUG
    printf("%s\n%ssocketBlockngMode[%s%I64d, %d%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        socketId, nonBlocking, 
        BLUE, RESET
    );
    #endif

    /*set blocking mode*/
    #ifdef _WIN32
    int iResult = ioctlsocket(socketId, FIONBIO, &nonBlocking);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    flags |= O_NONBLOCK;
    flags |= O_ASYNC;
    iResult = fcntl(socketId, F_SETFL, flags, &nonBlocking);
    #endif
    if (iResult != NO_ERROR) {
        #ifdef _DEBUG
        printf("%sERROR = %d%s\n\n", 
            RED, GETSOCKETERRNO(), RESET
        );
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
        printf("%sSuccess%s\n\n", 
            GREEN, RESET
        );
        #endif

    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR;
}

/*socketListen[socketId, backlog] -> successStatus*/
DLLEXPORT int socketListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int backlog = (int)MArgument_getInteger(Args[1]);

    #ifdef _DEBUG
    printf("%s\n%ssocketListen[%s%I64d%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        socketId, 
        BLUE, RESET
    );
    #endif

    /*wait clients*/
    int iResult = listen(socketId, backlog);
    if (iResult == SOCKET_ERROR) {
        #ifdef _DEBUG
        printf("%sERROR = %d%s\n\n", RED, GETSOCKETERRNO(), RESET);
        #endif

        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%sSuccess%s\n\n", 
        GREEN, RESET
    );
    #endif

    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*socketConnect[socketId, addressInfoPtr] -> successStatus*/
DLLEXPORT int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[1]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;
    bool wait = (bool)MArgument_getInteger(Args[2]); // wait for connection

    #ifdef _DEBUG
    printf("%s\n%ssocketConnect[%s%I64d, %p%s]%s -> ", 
        getCurrentTime(), 
        BLUE, RESET, 
        socketId, (void *)address, 
        BLUE, RESET
    );
    #endif

    bool blockingMode = blockingModeQ(socketId);

    if (wait && !blockingMode) {
        setBlocking(socketId, true); // set blocking mode if needed
    }

    int iResult = connect(socketId, address->ai_addr, (int)address->ai_addrlen);
    if (iResult == SOCKET_ERROR) {
        #ifdef _DEBUG
        printf("%sERROR = %d%s\n\n", RED, GETSOCKETERRNO(), RESET);
        #endif
        return LIBRARY_FUNCTION_ERROR;
    }

    if (wait && !blockingMode) {
        setBlocking(socketId, false); // restore non-blocking mode if needed
    }

    #ifdef _DEBUG
    printf("%sSuccess%s\n\n", GREEN, RESET);
    #endif

    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*socketsCheck[{sockets}, length] -> validSockets*/
DLLEXPORT int socketsCheck(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    MTensor socketsTensor = MArgument_getMTensor(Args[0]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets

    SOCKET *sockets = (SOCKET*)libData->MTensor_getIntegerData(socketsTensor);
    SOCKET sockedId;
    mint validCount = 0;
    int opt;
    int err;
    socklen_t len = sizeof(opt);

    #ifdef _DEBUG
    printf("%s[socketCheck->CALL]%s\n\tcheck(",
        GREEN, RESET); 
    #endif

    for (size_t i = 0; i < length; i++) {
        sockedId = sockets[i];

        #ifdef _DEBUG
        printf("%I64d ", sockedId); 
        #endif

        #ifdef _WIN32
        int result = getsockopt(sockedId, SOL_SOCKET, SO_TYPE, (char*)&opt, &len);
        #else
        int result = fcntl(sock, F_GETFL);
        #endif

        err = GETSOCKETERRNO();

        if (result >= 0 || 
            #ifdef _WIN32
            err != WSAENOTSOCK
            #else
            err != EBADF
            #endif
        ) {
            sockets[validCount] = sockedId;
            validCount++;
        }
    }

    #ifdef _DEBUG
    printf(")\n\n"); 
    #endif

    MTensor validSocketsList;
    libData->MTensor_new(MType_Integer, 1, &validCount, &validSocketsList);
    SOCKET *validSockets = (SOCKET*)libData->MTensor_getIntegerData(validSocketsList);

    #ifdef _DEBUG
    printf("%s[socketCheck->SUCCESS]%s\n\tcheck(",
        GREEN, RESET); 
    #endif

    for (mint i = 0; i < validCount; i++) {
        #ifdef _DEBUG
        printf("%I64d ", sockets[i]); 
        #endif
        validSockets[i] = sockets[i];
    }

    #ifdef _DEBUG
    printf(")\n\n"); 
    #endif
    
    MArgument_setMTensor(Res, validSocketsList);
    return LIBRARY_NO_ERROR;
}

/*socketAccept[socketId] -> clientId*/
DLLEXPORT int socketAccept(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    #ifdef _DEBUG
    printf("%s\n%ssocketAccept[%s%I64d%s]%s -> ", getCurrentTime(), BLUE, RESET, socketId, BLUE, RESET);
    #endif

    mutexLock(globalMutex);
    SOCKET client = accept(socketId, NULL, NULL);
    mutexUnlock(globalMutex);

    if (client == INVALID_SOCKET){
        int err = GETSOCKETERRNO();

        #ifdef _DEBUG
        printf("%sERROR = %d%s\n\n", RED, err, RESET);
        #endif

        acceptErrorMessage(libData, err);
        return LIBRARY_FUNCTION_ERROR;
    }

    #ifdef _DEBUG
    printf("%s%I64d%s\n\n", GREEN, client, RESET);
    #endif

    MArgument_setInteger(Res, client);
    return LIBRARY_NO_ERROR;
}

/*socketRecv[socketId, bufferPtr, bufferLength] -> byteArray*/
DLLEXPORT int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET client = (SOCKET)MArgument_getInteger(Args[0]);
    BYTE *buffer = (BYTE *)MArgument_getInteger(Args[1]);
    mint bufferSize = (mint)MArgument_getInteger(Args[2]);

    #ifdef _DEBUG
    printf("%s\n%sserverRecv[%s%I64d, buff = %d%s]%s -> ", getCurrentTime(), BLUE, RESET, client, bufferSize, BLUE, RESET);
    #endif

    mutexLock(globalMutex);
    int result = recv(client, buffer, bufferSize, 0);
    mutexUnlock(globalMutex);

    if (result > 0){
        mint len = (mint)result;
        MNumericArray byteArray;
        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &len, &byteArray);
        BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
        memcpy(array, buffer, result);

        #ifdef _DEBUG
        printf("%s%d bytes%s\n\n", GREEN, result, RESET);
        #endif

        free(buffer);
        MArgument_setMNumericArray(Res, byteArray);
        return LIBRARY_NO_ERROR;
    }
    
    free(buffer);
    int err = GETSOCKETERRNO();
    
    #ifdef _DEBUG
    printf("%sERROR = %d%s\n\n", RED, err, RESET);
    #endif

    recvErrorMessage(libData, err);
    return LIBRARY_FUNCTION_ERROR;
}

/*socketRecvFrom[socketId, addressPtr, bufferPtr, bufferLength] -> byteArray (only UDP)*/
DLLEXPORT int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET client = (SOCKET)MArgument_getInteger(Args[0]);
    BYTE *buffer = (BYTE *)MArgument_getInteger(Args[1]);
    mint bufferSize = (mint)MArgument_getInteger(Args[2]);
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[3]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    #ifdef _DEBUG
    printf("%s\n%sserverRecvFrom[%s%I64d%s]%s -> ", getCurrentTime(), BLUE, RESET, client, BLUE, RESET);
    #endif

    mutexLock(globalMutex);
    int result = recvfrom(client, buffer, bufferSize, 0, address, sizeof(struct addrinfo));
    mutexUnlock(globalMutex);

    if (result > 0){
        mint len = (mint)result;
        MNumericArray byteArray;
        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &len, &byteArray);
        BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
        memcpy(array, buffer, result);

        #ifdef _DEBUG
        printf("%s%d bytes%s\n\n", GREEN, result, RESET);
        #endif

        free(buffer);
        MArgument_setMNumericArray(Res, byteArray);
        return LIBRARY_NO_ERROR;
    }
    
    free(buffer);
    int err = GETSOCKETERRNO();
    
    #ifdef _DEBUG
    printf("%sERROR = %d%s\n\n", RED, err, RESET);
    #endif

    recvErrorMessage(libData, err);
    return LIBRARY_FUNCTION_ERROR;
}

/*socketSend[socketid, byteArray, length] -> sentLength*/
DLLEXPORT int socketSend(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = MArgument_getInteger(Args[0]); // positive integer
    MNumericArray mArr = MArgument_getMNumericArray(Args[1]); 
    int dataLength = MArgument_getInteger(Args[2]); // positive integer

    #ifdef _DEBUG
    printf("%s\n%ssocketSend[%s%d, %d bytes%s]%s -> ", getCurrentTime(), BLUE, RESET, socketId, dataLength, BLUE, RESET);
    #endif

    int result;
    BYTE *data = (BYTE*)libData->numericarrayLibraryFunctions->MNumericArray_getData(mArr);

    mutexLock(globalMutex);
    result = send(socketId, (char*)data, dataLength, 0);
    mutexUnlock(globalMutex);
    if (result > 0) {
        #ifdef _DEBUG
        printf("%s%d bytes%s\n\n", GREEN, result, RESET);
        #endif

        libData->numericarrayLibraryFunctions->MNumericArray_disown(mArr);
        MArgument_setInteger(Res, result);
        return LIBRARY_NO_ERROR;
    }

    libData->numericarrayLibraryFunctions->MNumericArray_disown(mArr);
    int err = GETSOCKETERRNO();

    #ifdef _DEBUG
    printf("%sERROR = %d%s\n\n", RED, err, RESET);
    #endif

    sendErrorMessage(libData, err);
    return LIBRARY_FUNCTION_ERROR;
}

/*socketSendString[socketid, text, length] -> sentLength*/
DLLEXPORT int socketSendString(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = MArgument_getInteger(Args[0]); // positive integer
    char *dataString = MArgument_getUTF8String(Args[1]); 
    int dataLength = MArgument_getInteger(Args[2]); // positive integer
    int result;

    mutexLock(globalMutex);
    result = send(socketId, dataString, dataLength, 0);
    mutexUnlock(globalMutex);
    if (result > 0) {
        #ifdef _DEBUG
        printf("%s\n%s[socketSend->SUCCESS]%s\n\tsend(socket id = %I64d) sent = %d bytes\n\n", 
            getCurrentTime(), GREEN, RESET, socketId, result);
        #endif

        libData->UTF8String_disown(dataString);
        MArgument_setInteger(Res, result);
        return LIBRARY_NO_ERROR;
    }
    libData->UTF8String_disown(dataString);
    
    int err = GETSOCKETERRNO();

    #ifdef _DEBUG
    printf("%s[socketSend->ERROR]%s\n\tsend(socket id = %I64d) returns error = %d\n\n", 
        RED, RESET, socketId, err);
    #endif

    sendErrorMessage(libData, err);
    return LIBRARY_FUNCTION_ERROR;
}

/*
    ASYNC EVENTS
*/

/*push list of sockets that ready for read*/
void pushSelect(WolframLibraryData libData, mint taskId, SOCKET *sockets, size_t socketsLength, fd_set *readset)
{
    SOCKET socketId;

    #ifdef _DEBUG
    size_t j;

    printf("%s\n%spushSelect[%s{%I64d", 
        getCurrentTime(), 
        BLUE, RESET, 
        sockets[0]
    );

    for (size_t i = 1; i < socketsLength; i++){
        socketId = sockets[i];
        printf(", %I64d", 
            socketId
        );
    }

    printf("} -> {");
    #endif

    DataStore data = libData->ioLibraryFunctions->createDataStore();
    for (size_t i = 0; i < socketsLength; i++) {
        socketId = sockets[i];
        if (FD_ISSET(socketId, &readset)) {
            libData->ioLibraryFunctions->DataStore_addInteger(data, socketId);
            
            #ifdef _DEBUG
            j++;
            if (j == 1) printf("%I64d", socketId);
            printf(", %I64d", socketId);
            #endif
        }

        #ifdef _DEBUG
        printf("}\n\n");
        #endif
    }
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Select", data);
}

/*push listen socket and new accepted socket*/
void pushAccept(WolframLibraryData libData, mint taskId, SOCKET listenSocket, SOCKET acceptedSocket)
{
    #ifdef _DEBUG
    printf("%s\n%pushAccept[%s%I64d%s]%s -> %I64d\n\n", 
        getCurrentTime(), 
        BLUE, RESET, 
        listenSocket, 
        BLUE, RESET, 
        acceptedSocket
    );
    #endif

    DataStore data = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(data, listenSocket);
    libData->ioLibraryFunctions->DataStore_addInteger(data, acceptedSocket);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Accept", data);
}

/*push listening tcp socket, source socket and received data*/
void pushRecv(WolframLibraryData libData, mint taskId, SOCKET listenSocket, SOCKET socketId, BYTE *buffer, int bufferLength)
{
    #ifdef _DEBUG
    printf("%s\n%spushRecv[%s%I64d, %I64d%s]%s -> %I64d bytes\n\n", 
        getCurrentTime(), 
        BLUE, RESET, 
        listenSocket, socketId, 
        BLUE, RESET, 
        bufferLength
    );
    #endif

    MNumericArray byteArray;
    libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &bufferLength, &byteArray);
    BYTE *byteArrayData = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
    memcpy(byteArrayData, buffer, bufferLength);

    DataStore data = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(data, listenSocket);
    libData->ioLibraryFunctions->DataStore_addInteger(data, socketId);
    libData->ioLibraryFunctions->DataStore_addMNumericArray(data, byteArray);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Recv", data);
}

/*push opened udp socket, from address and received data*/
void pushRecvFrom(WolframLibraryData libData, mint taskId, SOCKET socketId, struct sockaddr *address, BYTE *buffer, int bufferLength)
{
    #ifdef _DEBUG
    printf("%s\n%spushRecvFrom[%s%I64d, %p%s]%s -> %I64d", 
        getCurrentTime(), 
        BLUE, RESET, 
        socketId, address, 
        BLUE, RESET
    );
    #endif

    MNumericArray byteArray;
    libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &bufferLength, &byteArray);
    BYTE *byteArrayData = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
    memcpy(byteArrayData, buffer, bufferLength);

    DataStore data = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(data, socketId);
    libData->ioLibraryFunctions->DataStore_addInteger(data, address);
    libData->ioLibraryFunctions->DataStore_addMNumericArray(data, byteArray);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "RecvFrom", data);
}

/*push closed socket*/
void pushClose(WolframLibraryData libData, mint taskId, SOCKET socketId)
{
    #ifdef _DEBUG
    printf("%s\n%spushClose[%s%I64d%s]%s\n\n", 
        getCurrentTime(), 
        BLUE, RESET, 
        socketId, 
        BLUE, RESET
    );
    #endif

    DataStore data = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(data, socketId);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Close", data);
}

void serverSelect(Server server)
{
    fd_set *clientsReadSet = &server->clientsReadSet;
    #ifdef _WIN32
    struct timeval *tv = &server->timeout;
    #else
    struct timeval tv_copy = server->timeout;
    struct timeval *tv = &tv_copy;
    #endif
    int maxFd = server->listenSocket;

    FD_ZERO(clientsReadSet);
    FD_SET(maxFd, clientsReadSet);
    SOCKET client;

    #ifdef _DEBUG
    printf("%s\n%s[serverSelect->CALL]%s\n\tselect(len = %zd, timeout = %ld) sockets = (%ld",
        getCurrentTime(), 
        BLUE, RESET, 
        server->clientsLength + 1, server->timeout, server->listenSocket
    );
    #endif

    size_t count = server->clientsLength;
    for (size_t i = 0; i < count; i++)
    {
        client = server->clients[i];
        if (client != INVALID_SOCKET) {
            FD_SET(client, clientsReadSet);
            if (client > maxFd) maxFd = client;

            #ifdef _DEBUG
            printf(", %I64d", client);
            #endif
        }
    }

    #ifdef _DEBUG
    printf(")\n\n");
    #endif

    server->clientsReadSetLength = select(maxFd + 1, clientsReadSet, NULL, NULL, tv);
    if (server->clientsReadSetLength < 0) {
        int err = GETSOCKETERRNO();
        #ifdef _DEBUG
        printf("%s\n%s[serverSelect->ERROR]%s\n\tselect() returns error = %d\n\n", 
            getCurrentTime(), 
            RED, RESET, 
            err
        ); 
        #endif
    } else if (server->clientsReadSetLength > 0) {
        #ifdef _DEBUG
        printf("%s\n%s[serverSelect->SUCCESS]%s\n\tselect() returns %zd sockets\n\n", 
            getCurrentTime(),
            GREEN, RESET, 
            server->clientsReadSetLength
        );
        #endif
    } else {
        #ifdef _DEBUG
        printf("%s\n%s[serverSelect->SKIP]%s\n\tselect() returns 0 sockets\n\n", 
            getCurrentTime(),
            YELLOW, RESET
        );
        #endif
    }
}

void serverAccept(Server server)
{
    SOCKET listenSocket = server->listenSocket;

    #ifdef _DEBUG
    printf("%s\n%s[serverAccept->CALL]%s\n\taccept(listenSocket = %I64d)\n\n", 
        getCurrentTime(),
        BLUE, RESET, 
        listenSocket
    );
    #endif

    if (FD_ISSET(server->listenSocket, &server->clientsReadSet)) {
        server->clientsReadSetLength--;
        mutexLock(globalMutex);
        SOCKET client = accept(server->listenSocket, NULL, NULL);
        mutexUnlock(globalMutex);
        if (client != INVALID_SOCKET) {
            #ifdef _DEBUG
            printf("%s\n%s[serverAccept->SUCCESS]%s\n\taccept(listenSocket = %I64d) new client id = %I64d\n\n", 
                getCurrentTime(),
                GREEN, RESET, 
                listenSocket, client
            );
            #endif

            server->clients[server->clientsLength] = client;
            server->clientsLength++;
            pushAccept(server->libData, server->taskId, server->listenSocket, client);
        }
    } else {
        #ifdef _DEBUG
        printf("%s\n%s[serverAccept->SKIP]%s\n\taccept(listenSocket = %I64d) no new clients\n\n", 
            getCurrentTime(),
            YELLOW, RESET, 
            listenSocket
        );
        #endif
    }
}

void serverRecv(Server server)
{
    #ifdef _DEBUG
    printf("%s\n%s[serverRecv->CALL]%s\n\tlisten socket id = %I64d\n\tclients length = %zd\n\n", 
        getCurrentTime(),
        BLUE, RESET, 
        server->listenSocket, server->clientsLength
    );
    #endif
    int result;
    if (server->clientsReadSetLength > 0) {
        size_t count = server->clientsLength;
        fd_set *readfds = &server->clientsReadSet;
        SOCKET client;
        int readyCount = server->clientsReadSetLength;
        int j = 0;

        for (size_t i = 0; i < count; i++) {
            client = server->clients[i];
            if (client != INVALID_SOCKET && FD_ISSET(client, readfds)) {
                j++;
                mutexLock(globalMutex);
                result = recv(client, server->buffer, server->bufferSize, 0);
                mutexUnlock(globalMutex);
                int err = GETSOCKETERRNO();
                mint arrLen = (mint)result;
                if (result > 0) {
                    pushRecv(server->libData, server->taskId, server->listenSocket, client, server->buffer, result);
                } else if (result == 0 || (result < 0 && (err == 10038 || err == 10053))) {
                    #ifdef _DEBUG
                    printf("%s\n%s[serverRecv->ERROR]%s\n\tclient = %I64d\n\terror = %d\n\n", 
                        getCurrentTime(),
                        RED, RESET, 
                        client, err
                    );
                    #endif

                    server->clients[i] = INVALID_SOCKET;
                    pushClose(server->libData, server->taskId, client);
                } else {
                    #ifdef _DEBUG
                    printf("%s\n%s[serverRecv->ERROR]%s\n\tclient = %I64d\n\tunexpected error = %d\n\n", 
                        getCurrentTime(),
                        RED, RESET, 
                        client, err
                    );
                    #endif

                    server->clients[i] = INVALID_SOCKET;
                    pushClose(server->libData, server->taskId, client);
                }
            }

            if (j > readyCount) break;
        }

        #ifdef _DEBUG
        printf("%s\n%s[serverRecv->SUCCESS]%s\n\tlisten socket id = %I64d\n\tclients length = %zd\n\treceived data len = %d\n\n", 
            getCurrentTime(),
            GREEN, RESET, 
            server->listenSocket, server->clientsLength, result
        );
        #endif
    } else {
        #ifdef _DEBUG
        printf("%s\n%s[serverRecv->SKIP]%s\n\tlisten socket id = %I64d\n\tclients length = %zd\n\n", 
            getCurrentTime(),
            YELLOW, RESET, 
            server->listenSocket, server->clientsLength
        );
        #endif
    }
}

void serverCheck(Server server)
{
    #ifdef _DEBUG
    printf("%s\n%s[serverCheck->CALL]%s\n\tlisten socket id = %I64d\n\tclients length = %zd\n\n", 
        getCurrentTime(),
        BLUE, RESET, 
        server->listenSocket, server->clientsLength
    );
    #endif
    
    if (server->clientsReadSetLength <= 0) {
        SOCKET *sockets = server->clients;
        size_t count = server->clientsLength;
        SOCKET sock;
        mint validCount = 0;
        
        int opt;
        int err;
        socklen_t len = sizeof(opt);

        for (size_t i = 0; i < count; i++) {
            sock = sockets[i];

            if (sock > 0) {
                #ifdef _WIN32
                int result = getsockopt(sock, SOL_SOCKET, SO_TYPE, (char*)&opt, &len);
                #else
                int result = fcntl(sock, F_GETFL);
                #endif

                err = GETSOCKETERRNO();
                if (result >= 0 || 
                    #ifdef _WIN32
                    err != WSAENOTSOCK
                    #else
                    err != EBADF
                    #endif
                ) {
                    sockets[validCount] = sock;
                    validCount++;
                }
            }
        }

        server->clientsLength = validCount;
    } else {
        #ifdef _DEBUG
        printf("%s\n%s[serverCheck->SKIP]%s\n\tlisten socket id = %I64d\n\tclients length = %zd\n\n", 
            getCurrentTime(),
            YELLOW, RESET, 
            server->listenSocket, server->clientsLength
        );
        #endif
    }
}

static void serverListenerTask(mint taskId, void* vtarg)
{
    Server server = (Server)vtarg;
    
    #ifdef _DEBUG
    printf("%s\n%s[serverListenerTask->CALL]%s\n\tlisten socket id = %I64d\n\ttask id = %ld\n\n", 
        getCurrentTime(),
        BLUE, RESET, 
        server->listenSocket, taskId
    );
    #endif
    
    while (server->libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        serverSelect(server);
        serverCheck(server);
        serverAccept(server);
        serverRecv(server);
    }

    #ifdef _DEBUG
    printf("%s\n%s[serverListenerTask->END]%s\n\tlisten socket id = %I64d\n\ttask id = %ld\n\n", 
        getCurrentTime(),
        YELLOW, RESET, 
        server->listenSocket, taskId
    );
    #endif
}

/*serverListen[serverPtr] -> taskId*/
DLLEXPORT int serverListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    Server server = (Server)MArgument_getInteger(Args[0]);
    mint taskId;

    #ifdef _DEBUG
    printf("%s\n%s[serverListen->CALL]%s\n\tlisten socket id = %I64d\n\n", 
        getCurrentTime(),
        BLUE, RESET, 
        server->listenSocket
    );
    #endif

    taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(serverListenerTask, server);
    server->taskId = taskId;

    #ifdef _DEBUG
    printf("%s\n%s[serverListen->SUCCESS]%s\n\tlisten task id = %I64d\n\n", 
        getCurrentTime(),
        GREEN, RESET, 
        taskId
    );
    #endif

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

/*
    SELECT FUNCTIONS
*/

/*socketsSelect[{sockets}, length, timeout] -> {readySockets}*/
DLLEXPORT int socketsSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    MTensor socketIdsList = MArgument_getMTensor(Args[0]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets
    int timeout = (int)MArgument_getInteger(Args[2]); // timeout in microseconds

    int err;
    SOCKET *socketIds = (SOCKET*)libData->MTensor_getIntegerData(socketIdsList);
    SOCKET socketId;
    SOCKET maxFd = 0;
    fd_set readfds;
    FD_ZERO(&readfds);

    #ifdef _DEBUG
    printf("%s\n%ssocketSelect[%s", getCurrentTime(), BLUE, RESET); 
    #endif

    for (size_t i = 0; i < length; i++) {
        socketId = socketIds[i];
        if (socketId > maxFd) maxFd = socketId;
        FD_SET(socketId, &readfds);

        #ifdef _DEBUG
        if (i == 0) printf("%I64d", socketId);
        else printf(", %I64d", socketId);
        #endif
    }

    #ifdef _DEBUG
    printf("%s]%s -> ", BLUE, RESET);
    #endif

    struct timeval tv;
    tv.tv_sec  = timeout / 1000000;
    tv.tv_usec = timeout % 1000000;

    int result = select((int)(maxFd + 1), &readfds, NULL, NULL, &tv);
    if (result >= 0) {
        mint len = (mint)result;
        MTensor readySocketsTensor;
        libData->MTensor_new(MType_Integer, 1, &len, &readySocketsTensor);
        SOCKET *readySockets = (SOCKET*)libData->MTensor_getIntegerData(readySocketsTensor);
        
        #ifdef _DEBUG
        printf("%s{", GREEN);
        #endif

        int j = 0;
        for (size_t i = 0; i < length; i++) {
            socketId = socketIds[i];
            if (FD_ISSET(socketId, &readfds)) { 
                readySockets[j] = socketId;
                j++;

                #ifdef _DEBUG
                if (j == 1) printf("%I64d", socketId);
                else printf(", %I64d ", socketId);
                #endif
            }
        }

        #ifdef _DEBUG
        printf("}%s\n\n", RESET);
        #endif

        MArgument_setMTensor(Res, readySocketsTensor);
        return LIBRARY_NO_ERROR;
    } else {
        err = GETSOCKETERRNO();
        #ifdef _DEBUG
        printf("%sERROR = %d%s", RED, err, RESET); 
        #endif

        selectErrorMessage(libData, err);
        return LIBRARY_FUNCTION_ERROR;
    }
}

static void taskSelect(mint taskId, void* vtarg)
{
    SocketList socketList = (SocketList)vtarg;
    WolframLibraryData libData = socketList->libData;
    SOCKET *sockets = socketList->sockets;

    size_t length;
    SOCKET interrupt;
    SOCKET maxFd;
    struct timeval timeout;
    SOCKET socketId;
    int result;
    struct fd_set readfds;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        length = (size_t)socketList->length;
        interrupt = socketList->interrupt;
        maxFd = interrupt;

        FD_ZERO(&readfds);
        FD_SET(interrupt, &readfds);

        size_t length = (size_t)socketList->length;
        for (size_t i = 0; i < length; i++) {
            socketId = socketList->sockets[i];
            FD_SET(socketId, &readfds);
            if (socketId > maxFd) maxFd = socketId;
        }

        timeout.tv_sec = socketList->timeout / 1000000; // convert microseconds to seconds
        timeout.tv_usec = socketList->timeout % 1000000; // get remaining microseconds

        result = select(maxFd + 1, &readfds, NULL, NULL, &timeout);
        if (result > 0) {
            if (FD_ISSET(interrupt, &readfds)) {
                recv(interrupt, NULL, 0, 0);
            } else {
                pushSelect(libData, taskId, sockets, length, &readfds);
            }
        }
    }
}

/*createTaskSelect[socketList]*/
DLLEXPORT int createTaskSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    void *socketListPtr = (void *)MArgument_getInteger(Args[0]);

    #ifdef _DEBUG
    printf("%s\n%screateTaskSelect[%s%p%s]%s -> ", getCurrentTime(), BLUE, RESET, socketListPtr, BLUE, RESET);
    #endif

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(taskSelect, socketListPtr);
    
    #ifdef _DEBUG
    printf("%s%I64d%s\n\n", GREEN, taskId, RESET);
    #endif

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

static int socketListSelect(SocketList socketList, struct fd_set *readfds)
{
    size_t length;
    SOCKET interrupt;
    SOCKET maxFd;
    struct timeval timeout;
    SOCKET socketId;
    int result;

    length = (size_t)socketList->length;
    interrupt = socketList->interrupt;
    maxFd = interrupt;

    FD_ZERO(readfds);
    FD_SET(interrupt, readfds);

    for (size_t i = 0; i < length; i++) {
        socketId = socketList->sockets[i];
        FD_SET(socketId, readfds);
        if (socketId > maxFd) maxFd = socketId;
    }

    timeout.tv_sec = socketList->timeout / 1000000; // convert microseconds to seconds
    timeout.tv_usec = socketList->timeout % 1000000; // get remaining microseconds

    result = select(maxFd + 1, readfds, NULL, NULL, &timeout);
    return result;
}

static int serverSelectReady(Server server, struct fd_set *readfds)
{
    struct timeval timeout;
    SOCKET socketId;
    int result;

    size_t length = (size_t)server->clientsLength;
    SOCKET interrupt = server->interrupt;
    SOCKET maxFd = interrupt;

    FD_ZERO(readfds);
    FD_SET(interrupt, readfds);
    FD_SET(server->listenSocket, readfds);

    maxFd = max(interrupt, server->listenSocket);

    for (size_t i = 0; i < length; i++) {
        socketId = server->clients[i];
        FD_SET(socketId, readfds);
        if (socketId > maxFd) maxFd = socketId;
    }

    timeout.tv_sec = server->timeout / 1000000; // convert microseconds to seconds
    timeout.tv_usec = server->timeout % 1000000; // get remaining microseconds

    result = select(maxFd + 1, readfds, NULL, NULL, &timeout);
    return result;
}

static void taskSelectAcceptRecv(mint taskId, void* vtarg)
{
    Server server = (Server)vtarg;
    WolframLibraryData libData = server->libData;
    SOCKET *clients = server->clients;

    size_t length;
    SOCKET maxFd;
    struct timeval timeout;
    SOCKET socketId;
    int result;
    struct fd_set readfds;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        timeout.tv_sec = server->timeout / 1000000; // convert microseconds to seconds
        timeout.tv_usec = server->timeout % 1000000; // get remaining microseconds

        FD_ZERO(&readfds);
        FD_SET(server->interrupt, &readfds);
        FD_SET(server->listenSocket, &readfds);

        maxFd = max(server->interrupt, server->listenSocket);

        size_t length = (size_t)server->clientsLength;
        for (size_t i = 0; i < length; i++) {
            socketId = clients[i];
            FD_SET(socketId, &readfds);
            if (socketId > maxFd) maxFd = socketId;
        }
    }
    
}

/*createTaskSelectAcceptRecv[server]*/
DLLEXPORT int createTaskSelectAcceptRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    void *serverPtr = (void *)MArgument_getInteger(Args[0]);

    #ifdef _DEBUG
    printf("%s\n%screateTaskSelectAcceptRecv[%s%p%s]%s -> ", getCurrentTime(), BLUE, RESET, serverPtr, BLUE, RESET);
    #endif

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(taskSelectAcceptRecv, serverPtr);
    
    #ifdef _DEBUG
    printf("%s%I64d%s\n\n", GREEN, taskId, RESET);
    #endif

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

static void taskSelectRecvFrom(mint taskId, void *vtarg)
{
    SocketList socketList = (SocketList)vtarg;
    WolframLibraryData libData = socketList->libData;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        
    }
    
}

/*createTaskSelectAcceptRecv[{udpSockets}] -> taskId*/
DLLEXPORT int createTaskSelectRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    void *socketListPtr = (void *)MArgument_getInteger(Args[0]);

    #ifdef _DEBUG
    printf("%s\n%screateTaskSelectRecvFrom[%s%p%s]%s -> ", getCurrentTime(), BLUE, RESET, socketListPtr, BLUE, RESET);
    #endif

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(taskSelectRecvFrom, socketListPtr);
    
    #ifdef _DEBUG
    printf("%s%I64d%s\n\n", GREEN, taskId, RESET);
    #endif

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}