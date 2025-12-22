#include "internal.h"

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