#include "socket.h"


/* Release only the shared byte buffer acquired for this call. */
static int socket_call_result(WolframLibraryData libData, MArgument *args, int result, int byteArrayIndex)
{
    libData->numericarrayLibraryFunctions->MNumericArray_disown(MArgument_getMNumericArray(args[byteArrayIndex]));
    return result;
}


DLLEXPORT int socketCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketCreate: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    int family = (int)MArgument_getInteger(Args[0]);
    mint protocol = MArgument_getInteger(Args[1]);
    int socktype;

    if (protocol == IPPROTO_TCP) {
        socktype = SOCK_STREAM;
    } else if (protocol == IPPROTO_UDP) {
        socktype = SOCK_DGRAM;
    } else {
        libData->Message("socketCreate: invalid protocol");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET createdSocket = socket(family, socktype, (int)protocol);
    if (createdSocket == INVALID_SOCKET) {
        libData->Message("socketCreate: failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint socketId = (mint)createdSocket;
    MArgument_setInteger(Res, socketId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketClose(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketClose: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    int result = 0;

    if (ISVALIDSOCKET(socketId)) {
        result = CLOSESOCKET(socketId);
    }

    if (result == SOCKET_ERROR) {
        libData->Message("socketClose: failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketBind: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    char *numerichost = MArgument_getUTF8String(Args[1]);
    char *port = MArgument_getUTF8String(Args[2]);

    struct sockaddr_storage addressStorage = create_sockaddr_storage(numerichost, port);

    if (numerichost) libData->UTF8String_disown(numerichost);
    if (port) libData->UTF8String_disown(port);


    if (socketId == INVALID_SOCKET) {
        libData->Message("socketBind: invalid socket");
        return LIBRARY_FUNCTION_ERROR;
    }

    socklen_t addressSize = 0;
    switch (addressStorage.ss_family) {
    case AF_INET:
        addressSize = sizeof(struct sockaddr_in);
        break;
    case AF_INET6:
        addressSize = sizeof(struct sockaddr_in6);
        break;
    default:
        libData->Message("socketBind: unsupported address family");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (bind(socketId, (struct sockaddr *)&addressStorage, addressSize) == SOCKET_ERROR) {
        libData->Message("socketBind: failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketSetOpt: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);
    int optval = (int)MArgument_getInteger(Args[3]);

    if (setsockopt(socketId, level, optname, (const char*)&optval, sizeof(optval)) == SOCKET_ERROR) {
        libData->Message("socketSetOpt: failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketGetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketGetOpt: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);

    int optval = 0;
    socklen_t optlen = sizeof(optval);

    if (getsockopt(socketId, level, optname, (char*)&optval, &optlen) == SOCKET_ERROR) {
        libData->Message("socketGetOpt: failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, optval);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 1) {
        libData->Message("socketSetBlockingMode: failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    set_blocking_mode(socketId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetNonBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 1) {
        libData->Message("socketSetNonBlockingMode: failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    set_nonblocking_mode(socketId);
    return LIBRARY_NO_ERROR;
}


/* DataStore contains [local endpoint, remote endpoint]; missing endpoints are "". */
DLLEXPORT int socketGetAddresses(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketGetAddresses: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    mint role = MArgument_getInteger(Args[1]);
    struct sockaddr_storage addressStorage[2] = {0};

    switch (role) {
    case SOCKET_ROLE_UNDEFINED:
        break;
    case SOCKET_ROLE_BINDED:
    case SOCKET_ROLE_ACCEPTED:
    case SOCKET_ROLE_CONNECTED: {
        socklen_t length = sizeof(addressStorage[0]);
        if (getsockname(socketId, (struct sockaddr *)&addressStorage[0], &length) == SOCKET_ERROR) {
            ZeroMemory(&addressStorage[0], sizeof(addressStorage[0]));
        }
        if (role == SOCKET_ROLE_ACCEPTED || role == SOCKET_ROLE_CONNECTED) {
            length = sizeof(addressStorage[1]);
            if (getpeername(socketId, (struct sockaddr *)&addressStorage[1], &length) == SOCKET_ERROR) {
                ZeroMemory(&addressStorage[1], sizeof(addressStorage[1]));
            }
        }
        break;
    }
    default:
        libData->Message("socketGetAddresses: invalid role");
        return LIBRARY_FUNCTION_ERROR;
    }

    DataStore addresses = libData->ioLibraryFunctions->createDataStore();
    if (!addresses) return LIBRARY_MEMORY_ERROR;

    for (int i = 0; i < 2; i++) {
        char *endpoint = sockaddr_storage_to_string(addressStorage[i]);
        libData->ioLibraryFunctions->DataStore_addString(addresses, endpoint ? endpoint : "");
    }

    MArgument_setDataStore(Res, addresses);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketGetPort(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketGetPort: failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    struct sockaddr_storage addr;
    socklen_t len = sizeof(addr);

    if (getsockname(socketId, (struct sockaddr*)&addr, &len) != 0) {
        libData->Message("socketGetPort: failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (addr.ss_family == AF_INET) {
        mint port = ntohs(((struct sockaddr_in*)&addr)->sin_port);
        MArgument_setInteger(Res, port);
        return LIBRARY_NO_ERROR;
    }

    if (addr.ss_family == AF_INET6) {
        mint port = ntohs(((struct sockaddr_in6*)&addr)->sin6_port);
        MArgument_setInteger(Res, port);
        return LIBRARY_NO_ERROR;
    }

    return LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketGetHost(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketGetHost: failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    struct sockaddr_storage address;
    socklen_t length = sizeof(address);
    if (getsockname(socketId, (struct sockaddr *)&address, &length) == SOCKET_ERROR) {
        libData->Message("socketGetHost: getsockname failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    /* LibraryLink reads the string after the function returns. */
    static char host[INET6_ADDRSTRLEN];
    unsigned short port;
    if (!socket_address_to_host(&address, host, sizeof(host), &port)) {
        libData->Message("socketGetHost: unsupported address family");
        return LIBRARY_FUNCTION_ERROR;
    }
    MArgument_setUTF8String(Res, host);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 2) {
        libData->Message("socketListen: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    mint backlog = MArgument_getInteger(Args[1]);

    if (listen(socketId, (int)backlog) == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 3) {
        libData->Message("socketConnect: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    char *numerichost = MArgument_getUTF8String(Args[1]);
    char *port = MArgument_getUTF8String(Args[2]);
    struct sockaddr_storage addressStorage = create_sockaddr_storage(numerichost, port);
    if (numerichost) libData->UTF8String_disown(numerichost);
    if (port) libData->UTF8String_disown(port);

    socklen_t addressSize = 0;
    switch (addressStorage.ss_family) {
    case AF_INET:
        addressSize = sizeof(struct sockaddr_in);
        break;
    case AF_INET6:
        addressSize = sizeof(struct sockaddr_in6);
        break;
    default:
        libData->Message("Connect failed: unsupported address family");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (connect(socketId, (struct sockaddr *)&addressStorage, addressSize) == SOCKET_ERROR) {
        int err = GETSOCKETERRNO();
#ifdef _WIN32
        bool pending = err == WSAEWOULDBLOCK || err == WSAEINPROGRESS || err == WSAEALREADY;
#else
        bool pending = err == EINPROGRESS || err == EALREADY;
#endif
        if (!pending) return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketAccept(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketAccept: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    mbool nonBlocking = MArgument_getBoolean(Args[1]);
    SOCKET acceptedSocketId = accept(socketId, NULL, NULL);

    if (acceptedSocketId == INVALID_SOCKET) {
        return LIBRARY_FUNCTION_ERROR;
    }

    if (nonBlocking) set_nonblocking_mode(acceptedSocketId);
    else set_blocking_mode(acceptedSocketId);
    mint acceptedId = (mint)acceptedSocketId;
    MArgument_setInteger(Res, acceptedId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketRecv: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    MNumericArray buffer = MArgument_getMNumericArray(Args[1]);
    mint bufferSize = libData->numericarrayLibraryFunctions->MNumericArray_getFlattenedLength(buffer);
    if (bufferSize > INT_MAX) {
        libData->Message("socketRecv: buffer too large");
        return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 1);
    }
    BYTE *bufferData = libData->numericarrayLibraryFunctions->MNumericArray_getData(buffer);

    int result = recv(socketId, (char *)bufferData, (int)bufferSize, 0);
    if (result >= 0) {
        mint dataLength = result;
        MNumericArray receivedData;
        if (libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &dataLength, &receivedData)) {
            return socket_call_result(libData, Args, LIBRARY_MEMORY_ERROR, 1);
        }
        if (result > 0) memcpy(libData->numericarrayLibraryFunctions->MNumericArray_getData(receivedData), bufferData, (size_t)result);
        MArgument_setMNumericArray(Res, receivedData);
        return socket_call_result(libData, Args, LIBRARY_NO_ERROR, 1);
    }

    char errorMsg[32];
    snprintf(errorMsg, sizeof(errorMsg), "socketrecverror%d", GETSOCKETERRNO());
    libData->Message(errorMsg);
    return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 1);
}


DLLEXPORT int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketRecvFrom: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    MNumericArray buffer = MArgument_getMNumericArray(Args[1]);
    mint bufferSize = libData->numericarrayLibraryFunctions->MNumericArray_getFlattenedLength(buffer);
    if (bufferSize > INT_MAX) {
        libData->Message("socketRecvFrom: buffer too large");
        return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 1);
    }
    BYTE *bufferData = libData->numericarrayLibraryFunctions->MNumericArray_getData(buffer);

    struct sockaddr_storage addressStorage;
    ZeroMemory(&addressStorage, sizeof(addressStorage));
    socklen_t addressLength = sizeof(addressStorage);
    int result = recvfrom(socketId, (char *)bufferData, (int)bufferSize, 0,
        (struct sockaddr *)&addressStorage, &addressLength);
    if (result < 0) {
        char errorMsg[32];
        snprintf(errorMsg, sizeof(errorMsg), "socketrecvfromerror:%d", GETSOCKETERRNO());
        libData->Message(errorMsg);
        return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 1);
    }

    mint dataLength = (mint)result;
    MNumericArray receivedData;
    if (libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &dataLength, &receivedData)) {
        return socket_call_result(libData, Args, LIBRARY_MEMORY_ERROR, 1);
    }
    if (dataLength > 0) {
        memcpy(libData->numericarrayLibraryFunctions->MNumericArray_getData(receivedData), bufferData, (size_t)dataLength);
    }

    char *receivedAddress = sockaddr_storage_to_string(addressStorage);
    if (!receivedAddress) {
        libData->numericarrayLibraryFunctions->MNumericArray_free(receivedData);
        return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 1);
    }

    DataStore dataStore = libData->ioLibraryFunctions->createDataStore();
    if (!dataStore) {
        libData->numericarrayLibraryFunctions->MNumericArray_free(receivedData);
        return socket_call_result(libData, Args, LIBRARY_MEMORY_ERROR, 1);
    }
    libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, receivedData);
    libData->ioLibraryFunctions->DataStore_addString(dataStore, receivedAddress);
    MArgument_setDataStore(Res, dataStore);
    return socket_call_result(libData, Args, LIBRARY_NO_ERROR, 1);
}


DLLEXPORT int socketSend(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketSend: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    MNumericArray bytes = MArgument_getMNumericArray(Args[1]);
    mint length = MArgument_getInteger(Args[2]);
    if (length < 0 || length > INT_MAX || length > libData->numericarrayLibraryFunctions->MNumericArray_getFlattenedLength(bytes)) {
        return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 1);
    }
    BYTE *data = libData->numericarrayLibraryFunctions->MNumericArray_getData(bytes);

    int sentLength = send(socketId, (char*)data, (int)length, 0);

    if (sentLength < 0) {
        return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 1);
    }

    MArgument_setInteger(Res, sentLength);
    return socket_call_result(libData, Args, LIBRARY_NO_ERROR, 1);
}


DLLEXPORT int socketSendTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketSendTo: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    char *numerichost = MArgument_getUTF8String(Args[1]);
    char *port = MArgument_getUTF8String(Args[2]);
    struct sockaddr_storage addressStorage = create_sockaddr_storage(numerichost, port);
    if (numerichost) libData->UTF8String_disown(numerichost);
    if (port) libData->UTF8String_disown(port);

    socklen_t addressLength;
    switch (addressStorage.ss_family) {
    case AF_INET:
        addressLength = sizeof(struct sockaddr_in);
        break;
    case AF_INET6:
        addressLength = sizeof(struct sockaddr_in6);
        break;
    default:
        libData->Message("socketSendTo: unsupported address family");
        return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 3);
    }

    MNumericArray data = MArgument_getMNumericArray(Args[3]);
    mint length = libData->numericarrayLibraryFunctions->MNumericArray_getFlattenedLength(data);
    if (length > INT_MAX) {
        return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 3);
    }
    const char *bytes = libData->numericarrayLibraryFunctions->MNumericArray_getData(data);
    int sentLength = sendto(socketId, bytes, (int)length, 0,
        (const struct sockaddr *)&addressStorage, addressLength);

    if (sentLength == SOCKET_ERROR) return socket_call_result(libData, Args, LIBRARY_FUNCTION_ERROR, 3);
    MArgument_setInteger(Res, sentLength);
    return socket_call_result(libData, Args, LIBRARY_NO_ERROR, 3);
}


DLLEXPORT int socketsCheck(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketsCheck: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor sockets = MArgument_getMTensor(Args[0]);
    if (libData->MTensor_getRank(sockets) != 1) {
        libData->Message("socketsCheck: expected a list of socket descriptors");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint length = libData->MTensor_getFlattenedLength(sockets);
    mint *data = libData->MTensor_getIntegerData(sockets);

    mint *valid = NULL;
    if (length > 0) {
        valid = malloc((size_t)length * sizeof(mint));
        if (!valid) return LIBRARY_MEMORY_ERROR;
    }

    mint count = 0;
    for (mint i = 0; i < length; i++) {
        if (is_valid_socket((SOCKET)data[i])){
            valid[count] = data[i];
            count++;
        }
    }

    mint dims[1] = {count};
    MTensor validSockets;
    if (libData->MTensor_new(MType_Integer, 1, dims, &validSockets)) {
        free(valid);
        return LIBRARY_MEMORY_ERROR;
    }
    if (count > 0) {
        memcpy(libData->MTensor_getIntegerData(validSockets), valid, (size_t)count * sizeof(mint));
    }
    free(valid);
    MArgument_setMTensor(Res, validSockets);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketConnectedQ(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketConnectedQ: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    mbool blockingMode = MArgument_getBoolean(Args[1]); // True for blocking mode, False for non-blocking mode

    if (!ISVALIDSOCKET(socketId)) {
        MArgument_setBoolean(Res, False);
        return LIBRARY_NO_ERROR;
    }

    if (blockingMode) {
        set_nonblocking_mode(socketId);
    }

    char dummy;
    int ret = recv(socketId, &dummy, 1, MSG_PEEK);
    int err = GETSOCKETERRNO();

    if (blockingMode) {
        set_blocking_mode(socketId);
    }

    if (ret > 0) {
        MArgument_setBoolean(Res, True);
        return LIBRARY_NO_ERROR;
    }

    if (ret == 0) {
        MArgument_setBoolean(Res, False);
        return LIBRARY_NO_ERROR;
    }

    if (is_would_block_err(err)) {
        MArgument_setBoolean(Res, True);
        return LIBRARY_NO_ERROR;
    }

    MArgument_setBoolean(Res, False);
    return LIBRARY_NO_ERROR;
}


/* Returns rows {socketId, eventMask} for descriptors with nonzero revents. */
DLLEXPORT int socketsPoll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketsPoll: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor socketsTensor = MArgument_getMTensor(Args[0]);
    mint timeout = MArgument_getInteger(Args[1]);
    mint eventsMask = MArgument_getInteger(Args[2]);

    if (libData->MTensor_getRank(socketsTensor) != 1) {
        libData->Message("socketsPoll: expected a list of socket descriptors");
        return LIBRARY_FUNCTION_ERROR;
    }
    mint length = libData->MTensor_getFlattenedLength(socketsTensor);
    mint *socketArray = libData->MTensor_getIntegerData(socketsTensor);

    if (length == 0) {
        MTensor emptyTensor;
        mint dims[2] = {0, 2};
        if (libData->MTensor_new(MType_Integer, 2, dims, &emptyTensor)) return LIBRARY_MEMORY_ERROR;
        MArgument_setMTensor(Res, emptyTensor);
        return LIBRARY_NO_ERROR;
    }

    if ((size_t)length > SIZE_MAX / sizeof(POLL_FD)) return LIBRARY_MEMORY_ERROR;
    POLL_FD *fds = malloc(sizeof(POLL_FD) * (size_t)length);
    if (!fds) {
        libData->Message("socketsPoll: allocation failed for pollfds array");
        return LIBRARY_MEMORY_ERROR;
    }

    int nativeEvents = convert_wl_to_native_events(eventsMask);
    for (mint i = 0; i < length; i++) {
        fds[i].fd = (SOCKET)socketArray[i];
        fds[i].events = nativeEvents;
        fds[i].revents = 0;
    }

    int result = sockets_poll(fds, length, timeout);
    if (result < 0) {
        libData->Message("socketsPoll: poll failed");
        free(fds);
        return LIBRARY_FUNCTION_ERROR;
    }

    mint dims[2] = {result, 2};
    MTensor resultTensor;
    if (libData->MTensor_new(MType_Integer, 2, dims, &resultTensor)) {
        free(fds);
        return LIBRARY_MEMORY_ERROR;
    }
    mint *resultData = libData->MTensor_getIntegerData(resultTensor);

    mint idx = 0;
    for (mint i = 0; i < length && idx < result; i++) {
        if (fds[i].revents != 0) {
            resultData[2 * idx] = socketArray[i];
            resultData[2 * idx + 1] = convert_native_to_wl_events(fds[i].revents);
            idx++;
        }
    }

    free(fds);
    MArgument_setMTensor(Res, resultTensor);
    return LIBRARY_NO_ERROR;
}
