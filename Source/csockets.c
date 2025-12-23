#pragma region header

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

#pragma endregion

#pragma region internal

char* getCurrentTime() {
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

void initGlobalMutex() {
    #if defined(_WIN32)
        globalMutex = CreateMutex(NULL, FALSE, NULL);
    #else
        Mutex mutex = PTHREAD_MUTEX_INITIALIZER;
        globalMutex = mutex;
    #endif
}

void closeGlobalMutex() {
    #if defined(_WIN32) || defined(_WIN64)
    CloseHandle(globalMutex);
    #else
    pthread_mutex_destroy(&globalMutex);
    #endif
}

void lockGlobalMutex() {
    #if defined(_WIN32)
        WaitForSingleObject(globalMutex, INFINITE);
    #else
        pthread_mutex_lock(&globalMutex);
    #endif
}

void unlockGlobalMutex() {
    #if defined(_WIN32) || defined(_WIN64)
        ReleaseMutex(globalMutex);
    #else
        pthread_mutex_unlock(&globalMutex);
    #endif
}

void initWSA() {
    #ifdef _WIN32
    int iResult;
    WSADATA wsaData;

    iResult = WSAStartup(MAKEWORD(2,2), &wsaData);
    if (iResult != 0) return LIBRARY_FUNCTION_ERROR;
    #endif
}

void cleanupWSA() {
    #ifdef _WIN32
    WSACleanup();
    #else
    sleep(1);
    #endif
}

const int setBlockingMode(SOCKET socketId, bool blockingMode) {
    #ifdef _WIN32
    u_long mode = blockingMode ? 0 : 1; // 0 for blocking, 1 for non-blocking
    return ioctlsocket(socketId, FIONBIO, &mode);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    if (blockingMode) {
        return fcntl(socketId, F_SETFL, flags & ~O_NONBLOCK);
    } else {
        return fcntl(socketId, F_SETFL, flags | O_NONBLOCK);
    }
    #endif
}

const bool blockingModeQ(SOCKET socketId) {
    #ifdef _WIN32
    u_long mode;
    ioctlsocket(socketId, FIONBIO, &mode);
    return (mode == 0);
    #else
    int flags = fcntl(socketId, F_GETFL, 0);
    return !(flags & O_NONBLOCK);
    #endif
}

void acceptErrorMessage(WolframLibraryData libData, int err) {
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

void recvErrorMessage(WolframLibraryData libData, int err) {
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

void selectErrorMessage(WolframLibraryData libData, int err) {
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

void sendErrorMessage(WolframLibraryData libData, int err) {
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

void pushSelect(WolframLibraryData libData, mint taskId, SOCKET *sockets, size_t socketsLength, fd_set *readset) {
    SOCKET socketId;

    DataStore data = libData->ioLibraryFunctions->createDataStore();
    for (size_t i = 0; i < socketsLength; i++) {
        socketId = sockets[i];
        if (FD_ISSET(socketId, &readset)) {
            libData->ioLibraryFunctions->DataStore_addInteger(data, socketId);
        }
    }
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Select", data);
}

/*push listen socket and new accepted socket*/
void pushAccept(WolframLibraryData libData, mint taskId, SOCKET listenSocket, SOCKET acceptedSocket) {
    DataStore data = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(data, listenSocket);
    libData->ioLibraryFunctions->DataStore_addInteger(data, acceptedSocket);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Accept", data);
}

/*push listening tcp socket, source socket and received data*/
void pushRecv(WolframLibraryData libData, mint taskId, SOCKET listenSocket, SOCKET socketId, BYTE *buffer, int bufferLength) {
    MNumericArray byteArray;
    mint arrayLen = (mint)bufferLength;
    libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &arrayLen, &byteArray);
    BYTE *byteArrayData = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
    memcpy(byteArrayData, buffer, bufferLength);

    DataStore data = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(data, listenSocket);
    libData->ioLibraryFunctions->DataStore_addInteger(data, socketId);
    libData->ioLibraryFunctions->DataStore_addMNumericArray(data, byteArray);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Recv", data);
}

/*push opened udp socket, from address and received data*/
void pushRecvFrom(WolframLibraryData libData, mint taskId, SOCKET socketId, struct sockaddr *address, BYTE *buffer, int bufferLength) {
    MNumericArray byteArray;
    mint arrayLen2 = (mint)bufferLength;
    libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &arrayLen2, &byteArray);
    BYTE *byteArrayData = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
    memcpy(byteArrayData, buffer, bufferLength);

    DataStore data = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(data, socketId);
    libData->ioLibraryFunctions->DataStore_addInteger(data, (mint)(uintptr_t)address);
    libData->ioLibraryFunctions->DataStore_addMNumericArray(data, byteArray);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "RecvFrom", data);
}

/*push closed socket*/
void pushClose(WolframLibraryData libData, mint taskId, SOCKET socketId) {
    DataStore data = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(data, socketId);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Close", data);
}

const bool socketValidQ(SOCKET socketId) {
    #ifdef _WIN32
    int result = getsockopt(sockedId, SOL_SOCKET, SO_TYPE, (char*)&opt, &len);
    #else
    int result = fcntl(socketId, F_GETFL);
    #endif

    int err = GETSOCKETERRNO();

    return result >= 0 || 
        #ifdef _WIN32
        err != WSAENOTSOCK
        #else
        err != EBADF
        #endif
        ;
}

#pragma endregion

#pragma region public

DLLEXPORT mint WolframLibrary_getVersion() {
    return WolframLibraryVersion;
}

DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData) {
    initWSA();
    initGlobalMutex();
    return LIBRARY_NO_ERROR;
}

DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData) {
    unlockGlobalMutex();
    closeGlobalMutex();
    cleanupWSA();
    return;
}

/*socketAddressInfoCreate["host", "port", family, socktype, protocol] -> addressInfoPtr*/
DLLEXPORT int socketAddressInfoCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    char *host = MArgument_getUTF8String(Args[0]); // localhost by default
    char *port = MArgument_getUTF8String(Args[1]); // positive integer as string

    int ai_family = (int)MArgument_getInteger(Args[2]); // AF_UNSPEC == 0 | AF_INET == 2 | AF_INET6 == 23/10 | ..
    int ai_socktype = (int)MArgument_getInteger(Args[3]); // SOCK_STREAM == 1 | SOCK_DGRAM == 2 | SOCK_RAW == 3 | ..
    int ai_protocol = (int)MArgument_getInteger(Args[4]); // 0 | IPPROTO_TCP == 6 | IPPROTO_UDP == 17 | IPPROTO_SCTP == 132 | IPPROTO_ICMP == 1 | ..

    int result;
    struct addrinfo *address = NULL;
    struct addrinfo hints;

    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = ai_family;
    hints.ai_socktype = ai_socktype;
    hints.ai_protocol = ai_protocol;

    result = getaddrinfo(host, port, &hints, &address);
    if (result != 0) {
        libData->UTF8String_disown(host);
        libData->UTF8String_disown(port);
        return LIBRARY_FUNCTION_ERROR;
    }

    libData->UTF8String_disown(host);
    libData->UTF8String_disown(port);

    uintptr_t addressPtr = (uintptr_t)address;
    MArgument_setInteger(Res, (mint)addressPtr);
    return LIBRARY_NO_ERROR;
}

/*socketAddressInfoRemove[addressPtr] -> successStatus*/
DLLEXPORT int socketAddressInfoRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[0]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    if (address == NULL) {
        MArgument_setInteger(Res, 1); // failure
        return LIBRARY_FUNCTION_ERROR;
    }

    freeaddrinfo(address);
    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR;
}

/*socketAddressCreate[addressType] -> addressPtr*/
DLLEXPORT int socketAddressCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    struct sockaddr_in *address = malloc(sizeof(struct sockaddr_in));
    if (address == NULL) {
        return LIBRARY_FUNCTION_ERROR;
    }

    uintptr_t ptr = (uintptr_t)address;
    MArgument_setInteger(Res, (mint)ptr);
    return LIBRARY_NO_ERROR;
}

/*socketAddressRemove[addressPtr] -> successStatus*/
DLLEXPORT int socketAddressRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    uintptr_t ptr = (uintptr_t)MArgument_getInteger(Args[0]);
    struct sockaddr_in *address = (struct sockaddr_in *)ptr;

    free(address);
    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*socketBufferCreate[bufferSize] -> bufferPtr*/
DLLEXPORT int socketBufferCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    mint bufferSize = (mint)MArgument_getInteger(Args[0]);
    BYTE *buffer = malloc(bufferSize * sizeof(BYTE));
    uintptr_t bufferPtr = (uintptr_t)buffer;
    MArgument_setInteger(Res, bufferPtr);
    return LIBRARY_NO_ERROR;
}
 
/*socketBufferRemove[bufferPtr] -> successStatus*/
DLLEXPORT int socketBufferRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    BYTE * buffer = (BYTE *)MArgument_getInteger(Args[0]);
    free(buffer);
    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*socketCreate[family, socktype, protocol] -> socketId*/
DLLEXPORT int socketCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    int family = (int)MArgument_getInteger(Args[0]); // family
    int socktype = (int)MArgument_getInteger(Args[1]); // sock type
    int protocol = (int)MArgument_getInteger(Args[2]); // protocol

    SOCKET createdSocket = socket(family, socktype, protocol);
    if (createdSocket == INVALID_SOCKET) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, createdSocket); // return socket id
    return LIBRARY_NO_ERROR;
}

/*socketCreate[socketId] -> successStatus*/
DLLEXPORT int socketClose(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = MArgument_getInteger(Args[0]); // positive integer

    mint result = true;

    if (socketId > 0) {
        lockGlobalMutex();
        result = CLOSESOCKET(socketId);
        unlockGlobalMutex();
    }

    if (result == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, result);
    return LIBRARY_NO_ERROR;
}

/*socketBind[socketId, addressPtr] -> successStatus*/
DLLEXPORT int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket for binding
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[1]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    bool successState = 0;

    if (address == NULL) {
        return LIBRARY_FUNCTION_ERROR;
    }

    if (socketId == INVALID_SOCKET) {
        return LIBRARY_FUNCTION_ERROR;
    }

    int iResult = bind(socketId, address->ai_addr, (int)address->ai_addrlen);
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, successState); // success = 0
    return LIBRARY_NO_ERROR;
}

/*socketSetOpt[socketId, level, optName, optVal] -> successStatus*/
DLLEXPORT int socketSetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);
    int optval = (int)MArgument_getInteger(Args[3]);

    int iResult = setsockopt(socketId, level, optname, (const char*)&optval, sizeof(optval));
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR;
}

/*socketGetOpt[socketId, level, optName] -> optVal*/
DLLEXPORT int socketGetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket id
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);

    int optval = 0;
    socklen_t optlen = sizeof(optval);

    int iResult = getsockopt(socketId, level, optname, (char*)&optval, &optlen);
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, optval); // return retrieved value
    return LIBRARY_NO_ERROR;
}

/*socketSetBlockingMode[socketId, mode] -> successStatus*/
DLLEXPORT int socketSetBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket
    int blockingMode = (int)MArgument_getInteger(Args[1]); // 0 | 1 default 0 == blocking mode
    
    int iResult = setBlockingMode(socketId, blockingMode);
    if (iResult != NO_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, 0); // success
    return LIBRARY_NO_ERROR;
}

/*socketListen[socketId, backlog] -> successStatus*/
DLLEXPORT int socketListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int backlog = (int)MArgument_getInteger(Args[1]);

    /*wait clients*/
    int iResult = listen(socketId, backlog);
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*socketConnect[socketId, addressInfoPtr] -> successStatus*/
DLLEXPORT int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[1]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;
    bool wait = (bool)MArgument_getInteger(Args[2]); // wait for connection

    bool blockingMode = blockingModeQ(socketId);
    if (wait && !blockingMode) {
        setBlockingMode(socketId, true); // set blocking mode if needed
    }

    int iResult = connect(socketId, address->ai_addr, (int)address->ai_addrlen);
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    if (wait && !blockingMode) {
        setBlockingMode(socketId, false); // restore non-blocking mode if needed
    }

    MArgument_setInteger(Res, 0);
    return LIBRARY_NO_ERROR;
}

/*socketAccept[socketId] -> clientId*/
DLLEXPORT int socketAccept(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    lockGlobalMutex();
    SOCKET client = accept(socketId, NULL, NULL);
    unlockGlobalMutex();
    
    if (client == INVALID_SOCKET) {
        int err = GETSOCKETERRNO();
        acceptErrorMessage(libData, err);
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, client);
    return LIBRARY_NO_ERROR;
}

/*socketRecv[socketId, bufferPtr, bufferLength] -> byteArray*/
DLLEXPORT int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET client = (SOCKET)MArgument_getInteger(Args[0]);
    BYTE *buffer = (BYTE *)MArgument_getInteger(Args[1]);
    mint bufferSize = (mint)MArgument_getInteger(Args[2]);

    lockGlobalMutex();
    int result = recv(client, buffer, bufferSize, 0);
    unlockGlobalMutex();

    if (result > 0) {
        mint len = (mint)result;
        MNumericArray byteArray;
        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &len, &byteArray);
        BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
        memcpy(array, buffer, result);
        free(buffer);
        MArgument_setMNumericArray(Res, byteArray);
        return LIBRARY_NO_ERROR;
    }
    
    free(buffer);
    int err = GETSOCKETERRNO();
    recvErrorMessage(libData, err);
    return LIBRARY_FUNCTION_ERROR;
}

/*socketRecvFrom[socketId, addressPtr, bufferPtr, bufferLength] -> byteArray (only UDP)*/
DLLEXPORT int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET client = (SOCKET)MArgument_getInteger(Args[0]);
    BYTE *buffer = (BYTE *)MArgument_getInteger(Args[1]);
    mint bufferSize = (mint)MArgument_getInteger(Args[2]);
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[3]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    socklen_t addrlen = sizeof(struct sockaddr);
    lockGlobalMutex();
    int result = recvfrom(client, buffer, bufferSize, 0, address->ai_addr, &addrlen);
    unlockGlobalMutex();

    if (result > 0) {
        mint len = (mint)result;
        MNumericArray byteArray;
        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &len, &byteArray);
        BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
        memcpy(array, buffer, result);

        free(buffer);
        MArgument_setMNumericArray(Res, byteArray);
        return LIBRARY_NO_ERROR;
    }
    
    free(buffer);
    int err = GETSOCKETERRNO();
    recvErrorMessage(libData, err);
    return LIBRARY_FUNCTION_ERROR;
}

/*socketSend[socketid, byteArray, length] -> sentLength*/
DLLEXPORT int socketSend(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = MArgument_getInteger(Args[0]); // positive integer
    MNumericArray mArr = MArgument_getMNumericArray(Args[1]); 
    int dataLength = MArgument_getInteger(Args[2]); // positive integer

    int result;
    BYTE *data = (BYTE*)libData->numericarrayLibraryFunctions->MNumericArray_getData(mArr);

    lockGlobalMutex();
    result = send(socketId, (char*)data, dataLength, 0);
    unlockGlobalMutex();
    if (result > 0) {
        libData->numericarrayLibraryFunctions->MNumericArray_disown(mArr);
        MArgument_setInteger(Res, result);
        return LIBRARY_NO_ERROR;
    }

    libData->numericarrayLibraryFunctions->MNumericArray_disown(mArr);
    int err = GETSOCKETERRNO();

    sendErrorMessage(libData, err);
    return LIBRARY_FUNCTION_ERROR;
}

/*socketSendString[socketid, text, length] -> sentLength*/
DLLEXPORT int socketSendString(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = MArgument_getInteger(Args[0]); // positive integer
    char *dataString = MArgument_getUTF8String(Args[1]); 
    int dataLength = MArgument_getInteger(Args[2]); // positive integer
    int result;

    lockGlobalMutex();
    result = send(socketId, dataString, dataLength, 0);
    unlockGlobalMutex();

    if (result > 0) {
        libData->UTF8String_disown(dataString);
        MArgument_setInteger(Res, result);
        return LIBRARY_NO_ERROR;
    }

    libData->UTF8String_disown(dataString);
    
    int err = GETSOCKETERRNO();
    sendErrorMessage(libData, err);
    return LIBRARY_FUNCTION_ERROR;
}

/*socketsCheck[{sockets}, length] -> validSockets*/
DLLEXPORT int socketsCheck(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    MTensor socketsTensor = MArgument_getMTensor(Args[0]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets

    SOCKET *sockets = (SOCKET*)libData->MTensor_getIntegerData(socketsTensor);
    SOCKET socketId;
    mint validCount = 0;
    int opt;
    int err;
    socklen_t len = sizeof(opt);

    for (size_t i = 0; i < length; i++) {
        socketId = sockets[i];

        if (socketValidQ(socketId)) {
            sockets[validCount] = socketId;
            validCount++;
        }
    }

    MTensor validSocketsList;
    libData->MTensor_new(MType_Integer, 1, &validCount, &validSocketsList);
    SOCKET *validSockets = (SOCKET*)libData->MTensor_getIntegerData(validSocketsList);

    for (mint i = 0; i < validCount; i++) {
        validSockets[i] = sockets[i];
    }

    MArgument_setMTensor(Res, validSocketsList);
    return LIBRARY_NO_ERROR;
}

/*socketsSelect[{sockets}, length, timeout] -> {readySockets}*/
DLLEXPORT int socketsSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    MTensor socketIdsList = MArgument_getMTensor(Args[0]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets
    int timeout = (int)MArgument_getInteger(Args[2]); // timeout in microseconds

    int err;
    SOCKET *socketIds = (SOCKET*)libData->MTensor_getIntegerData(socketIdsList);
    SOCKET socketId;
    SOCKET maxFd = 0;
    fd_set readfds;
    FD_ZERO(&readfds);

    for (size_t i = 0; i < length; i++) {
        socketId = socketIds[i];
        if (socketId > maxFd) maxFd = socketId;
        FD_SET(socketId, &readfds);
    }

    struct timeval tv;
    tv.tv_sec  = timeout / 1000000;
    tv.tv_usec = timeout % 1000000;

    int result = select((int)(maxFd + 1), &readfds, NULL, NULL, &tv);
    if (result >= 0) {
        mint len = (mint)result;
        MTensor readySocketsTensor;
        libData->MTensor_new(MType_Integer, 1, &len, &readySocketsTensor);
        SOCKET *readySockets = (SOCKET*)libData->MTensor_getIntegerData(readySocketsTensor);

        int j = 0;
        for (size_t i = 0; i < length; i++) {
            socketId = socketIds[i];
            if (FD_ISSET(socketId, &readfds)) { 
                readySockets[j] = socketId;
                j++;
            }
        }

        MArgument_setMTensor(Res, readySocketsTensor);
        return LIBRARY_NO_ERROR;
    } else {
        err = GETSOCKETERRNO();
        selectErrorMessage(libData, err);
        return LIBRARY_FUNCTION_ERROR;
    }
}

#pragma endregion