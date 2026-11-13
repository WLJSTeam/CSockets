#include "socket.h"
#include "address.h"
#include <limits.h>


bool socket_objects_valid(WolframLibraryData libData, MTensor tensor, mint length)
{
    if (length == 0 && libData->MTensor_getFlattenedLength(tensor) == 0) return true;
    return length >= 0 && libData->MTensor_getRank(tensor) == 2 &&
        libData->MTensor_getDimensions(tensor)[0] == length && libData->MTensor_getDimensions(tensor)[1] == 6;
}

void DataStore_addSocketObject(WolframLibraryData libData, DataStore store, SocketObject socketObject)
{
    mint dims[1] = {6};
    MTensor tensor;
    libData->MTensor_new(MType_Integer, 1, dims, &tensor);
    memcpy(libData->MTensor_getIntegerData(tensor), &socketObject, sizeof(SocketObject));
    libData->ioLibraryFunctions->DataStore_addMTensor(store, tensor);
}

SocketObject *MArgument_getSocketObject(WolframLibraryData libData, MArgument arg)
{
    MTensor tensor = MArgument_getMTensor(arg);
    if (libData->MTensor_getRank(tensor) != 1 || libData->MTensor_getDimensions(tensor)[0] != 6) {
        libData->Message("SocketObject requires six integers");
        return NULL;
    }
    return (SocketObject *)libData->MTensor_getIntegerData(tensor);
}


void MArgument_setSocketObject(WolframLibraryData libData, MArgument Res, SocketObject socketObject)
{
    mint dims[1] = {6};
    MTensor tensor;
    libData->MTensor_new(MType_Integer, 1, dims, &tensor);

    SocketObject *data = (SocketObject *)libData->MTensor_getIntegerData(tensor);
    *data = socketObject;

    MArgument_setMTensor(Res, tensor);
}


void MArgument_disownSocketObject(WolframLibraryData libData, MArgument arg)
{
    MTensor tensor = MArgument_getMTensor(arg);
    libData->MTensor_disownAll(tensor);
}


BYTE *MArgument_getByteArray(WolframLibraryData libData, MArgument arg)
{
    MNumericArray byteArray = MArgument_getMNumericArray(arg);
    BYTE *array = (BYTE*)libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
    libData->numericarrayLibraryFunctions->MNumericArray_disown(byteArray);
    
    return array;
}


void MArgument_setByteArray(WolframLibraryData libData, MArgument Res, BYTE *data, mint length)
{
    MNumericArray byteArray;
    libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &length, &byteArray);

    if (length > 0) {
        BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
        memcpy(array, data, (size_t)length);
    }

    MArgument_setMNumericArray(Res, byteArray);
}


DLLEXPORT int socketCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("Create failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    int family = (int)MArgument_getInteger(Args[0]);
    int socktype = (int)MArgument_getInteger(Args[1]);
    int protocol = (int)MArgument_getInteger(Args[2]);

    if (socktype != SOCK_STREAM && socktype != SOCK_DGRAM) {
        libData->Message("Create failed: invalid type");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (protocol != SOCKET_PROTOCOL_AUTO &&
        protocol != SOCKET_PROTOCOL_TCP &&
        protocol != SOCKET_PROTOCOL_UDP) {
        libData->Message("Create failed: invalid protocol");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET createdSocket = socket(family, socktype, protocol);
    if (createdSocket == INVALID_SOCKET) {
        libData->Message("Create failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketObject socketObject = {
        .socket = (int64_t)createdSocket,
        .protocol = (int64_t)protocol,
        .type = (int64_t)socktype,
        .role = (int64_t)SOCKET_ROLE_INTERRUPTER,
        .state = (int64_t)SOCKET_STATE_ALIVE,
        .mode = (int64_t)SOCKET_MODE_BLOCKING
    };

    MArgument_setSocketObject(libData, Res, socketObject);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketClose(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketClose: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    SOCKET socketId = (SOCKET)socketObject->socket;

    mint result = true;

    if (ISVALIDSOCKET(socketId)) {
        result = CLOSESOCKET(socketId);
    }

    if (result == SOCKET_ERROR) {
        libData->Message("Close failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    socketObject->socket = (int64_t)INVALID_SOCKET;
    socketObject->state = (int64_t)SOCKET_STATE_CLOSED;

    MArgument_disownSocketObject(libData, Args[0]);

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 2) {
        libData->Message("socketBind: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    SOCKET socketId = (SOCKET)socketObject->socket;
    struct sockaddr_storage *addressStorage = MArgument_getAddressStorage(libData, Args[1]);
    if (addressStorage == NULL) {
        libData->Message("Bind failed: invalid address data");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (socketId == INVALID_SOCKET) {
        libData->Message("Bind failed: invalid socket");
        return LIBRARY_FUNCTION_ERROR;
    }

    socklen_t addressSize = 0;
    switch (addressStorage->ss_family) {
    case AF_INET:
        addressSize = sizeof(struct sockaddr_in);
        break;
    case AF_INET6:
        addressSize = sizeof(struct sockaddr_in6);
        break;
    default:
        libData->Message("Bind failed: unsupported address family");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (bind(socketId, (struct sockaddr *)addressStorage, addressSize) == SOCKET_ERROR) {
        libData->Message("Bind failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (socketObject->type == SOCKET_TYPE_DGRAM) {
        socketObject->role = (int64_t)SOCKET_ROLE_LISTENER;
    }
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 4) {
        libData->Message("socketSetOpt: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    SOCKET socketId = (SOCKET)socketObject->socket;
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);
    int optval = (int)MArgument_getInteger(Args[3]);

    if (setsockopt(socketId, level, optname, (const char*)&optval, sizeof(optval)) == SOCKET_ERROR) {
        libData->Message("SetOpt failed");
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
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    SOCKET socketId = (SOCKET)socketObject->socket;
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);

    int optval = 0;
    socklen_t optlen = sizeof(optval);

    if (getsockopt(socketId, level, optname, (char*)&optval, &optlen) == SOCKET_ERROR) {
        libData->Message("GetOpt failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, optval);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 1) {
        libData->Message("SetBlockingMode failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;

    set_blocking_mode((SOCKET)socketObject->socket);
    socketObject->mode = (int64_t)SOCKET_MODE_BLOCKING;
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetNonBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 1) {
        libData->Message("SetNonBlockingMode failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;

    set_non_blocking_mode((SOCKET)socketObject->socket);
    socketObject->mode = (int64_t)SOCKET_MODE_NONBLOCKING;
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketGetPort(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("GetPort failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    struct sockaddr_storage addr;
    socklen_t len = sizeof(addr);

    if (getsockname((SOCKET)socketObject->socket, (struct sockaddr*)&addr, &len) != 0) {
        libData->Message("GetPort failed");
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
    if (Argc != 1) return LIBRARY_FUNCTION_ERROR;
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;

    struct sockaddr_storage address;
    socklen_t length = sizeof(address);
    if (getsockname((SOCKET)socketObject->socket, (struct sockaddr *)&address, &length) == SOCKET_ERROR) {
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

    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    SOCKET socketId = (SOCKET)socketObject->socket;
    mint backlog = MArgument_getInteger(Args[1]);

    if (listen(socketId, (int)backlog) == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    socketObject->role = (int64_t)SOCKET_ROLE_LISTENER;
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 2) {
        libData->Message("socketConnect: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    struct sockaddr_storage *addressStorage = MArgument_getAddressStorage(libData, Args[1]);
    if (addressStorage == NULL) {
        libData->Message("Connect failed: invalid address data");
        return LIBRARY_FUNCTION_ERROR;
    }

    socklen_t addressSize = 0;
    switch (addressStorage->ss_family) {
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

    if (connect((SOCKET)socketObject->socket, (struct sockaddr *)addressStorage, addressSize) == SOCKET_ERROR) {
        int err = GETSOCKETERRNO();
#ifdef _WIN32
        bool pending = err == WSAEWOULDBLOCK || err == WSAEINPROGRESS || err == WSAEALREADY;
#else
        bool pending = err == EINPROGRESS || err == EALREADY;
#endif
        if (socketObject->mode != SOCKET_MODE_NONBLOCKING || !pending) return LIBRARY_FUNCTION_ERROR;
    }

    socketObject->role = (int64_t)SOCKET_ROLE_CONNECTED;
    socketObject->state = (int64_t)SOCKET_STATE_ALIVE;
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketAccept(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketAccept: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *listenSocket = MArgument_getSocketObject(libData, Args[0]);
    if (!listenSocket) return LIBRARY_FUNCTION_ERROR;
    SOCKET acceptedSocketId = accept((SOCKET)listenSocket->socket, NULL, NULL);

    if (acceptedSocketId == INVALID_SOCKET) {
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketObject acceptedSocketObject = {
        .socket = (int64_t)acceptedSocketId,
        .protocol = (int64_t)SOCKET_PROTOCOL_TCP,
        .type = (int64_t)SOCKET_TYPE_STREAM,
        .role = (int64_t)SOCKET_ROLE_ACCEPTED,
        .state = (int64_t)SOCKET_STATE_ALIVE,
        .mode = listenSocket->mode
    };

    if (acceptedSocketObject.mode == SOCKET_MODE_NONBLOCKING) set_non_blocking_mode(acceptedSocketId);
    else set_blocking_mode(acceptedSocketId);
    MArgument_setSocketObject(libData, Res, acceptedSocketObject);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketRecv: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    BYTE *buffer = MArgument_getByteArray(libData, Args[1]);
    mint bufferSize = MArgument_getInteger(Args[2]);

    int result = recv((SOCKET)socketObject->socket, buffer, bufferSize, 0);
    if (result >= 0) {
        MArgument_setByteArray(libData, Res, buffer, result);
        return LIBRARY_NO_ERROR;
    }

    char errorMsg[32];
    snprintf(errorMsg, sizeof(errorMsg), "socketrecverror%d", GETSOCKETERRNO());
    libData->Message(errorMsg);
    return LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketRecvFrom: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    struct sockaddr_storage *addressStorage = MArgument_getAddressStorage(libData, Args[1]);
    BYTE *buffer = MArgument_getByteArray(libData, Args[2]);
    mint bufferSize = MArgument_getInteger(Args[3]);

    if (addressStorage == NULL) {
        libData->Message("socketRecvFrom: invalid address data");
        return LIBRARY_FUNCTION_ERROR;
    }

    socklen_t addrLen = 0;
    switch (addressStorage->ss_family) {
    case AF_INET:
        addrLen = sizeof(struct sockaddr_in);
        break;
    case AF_INET6:
        addrLen = sizeof(struct sockaddr_in6);
        break;
    default:
        libData->Message("socketRecvFrom: unsupported address family");
        return LIBRARY_FUNCTION_ERROR;
    }

    int result = recvfrom((SOCKET)socketObject->socket, buffer, bufferSize, 0, (struct sockaddr *)addressStorage, &addrLen);
    if (result >= 0) {
        MArgument_setByteArray(libData, Res, buffer, (mint)result);
        return LIBRARY_NO_ERROR;
    }

    char errorMsg[32];
    snprintf(errorMsg, sizeof(errorMsg), "socketrecvfromerror:%d", GETSOCKETERRNO());
    libData->Message(errorMsg);
    return LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketSend(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketSend: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    BYTE *data = MArgument_getByteArray(libData, Args[1]);
    int length = MArgument_getInteger(Args[2]);

    int sentLength = send((SOCKET)socketObject->socket, (char*)data, (int)length, 0);

    if (sentLength < 0) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSendString(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketSendString: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    char *text = MArgument_getUTF8String(Args[1]);
    size_t length = strlen(text);

    int sentLength = send((SOCKET)socketObject->socket, text, (int)length, 0);
    libData->UTF8String_disown(text);

    if (sentLength < 0) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSendTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 5) {
        libData->Message("socketSendTo: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    char *host = MArgument_getUTF8String(Args[1]);
    unsigned short port = (unsigned short)MArgument_getInteger(Args[2]);

    BYTE *data = MArgument_getByteArray(libData, Args[3]);
    mint length = MArgument_getInteger(Args[4]);

    struct sockaddr_storage address;
    socklen_t addressLength;

    if (!socket_address_from_host(host, port, &address, &addressLength))
    {
        libData->UTF8String_disown(host);
        return LIBRARY_FUNCTION_ERROR;
    }

    int sentLength = sendto((SOCKET)socketObject->socket, (const char *)data, (int)length, 0, (const struct sockaddr *)&address, addressLength);

    libData->UTF8String_disown(host);

    if (sentLength < 0)
    {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSendToAddressStorage(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketSendToAddressStorage: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    struct sockaddr_storage *addressStorage = MArgument_getAddressStorage(libData, Args[1]);
    if (!addressStorage) return LIBRARY_FUNCTION_ERROR;

    socklen_t addressLength;
    switch (addressStorage->ss_family) {
    case AF_INET:
        addressLength = sizeof(struct sockaddr_in);
        break;
    case AF_INET6:
        addressLength = sizeof(struct sockaddr_in6);
        break;
    default:
        libData->Message("socketSendToAddressStorage: unsupported address family");
        return LIBRARY_FUNCTION_ERROR;
    }

    MNumericArray data = MArgument_getMNumericArray(Args[2]);
    mint length = libData->numericarrayLibraryFunctions->MNumericArray_getFlattenedLength(data);
    if (length > INT_MAX) {
        libData->numericarrayLibraryFunctions->MNumericArray_disown(data);
        return LIBRARY_FUNCTION_ERROR;
    }
    const char *bytes = libData->numericarrayLibraryFunctions->MNumericArray_getData(data);
    int sentLength = sendto((SOCKET)socketObject->socket, bytes, (int)length, 0,
        (const struct sockaddr *)addressStorage, addressLength);
    libData->numericarrayLibraryFunctions->MNumericArray_disown(data);

    if (sentLength == SOCKET_ERROR) return LIBRARY_FUNCTION_ERROR;
    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSendStringTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketSendStringTo: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;

    char *host = MArgument_getUTF8String(Args[1]);
    unsigned short port = (unsigned short)MArgument_getInteger(Args[2]);

    char *text = MArgument_getUTF8String(Args[3]);
    size_t length = strlen(text);

    struct sockaddr_storage address;
    socklen_t addressLength;

    if (!socket_address_from_host(host, port, &address, &addressLength))
    {
        libData->UTF8String_disown(host);
        libData->UTF8String_disown(text);
        return LIBRARY_FUNCTION_ERROR;
    }

    int sentLength = sendto((SOCKET)socketObject->socket, text, (int)length, 0, (const struct sockaddr *)&address, addressLength);

    libData->UTF8String_disown(host);
    libData->UTF8String_disown(text);

    if (sentLength < 0)
    {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketsCheck(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketsCheck: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor sockets = MArgument_getMTensor(Args[0]);
    size_t length = (size_t)MArgument_getInteger(Args[1]);

    if (!socket_objects_valid(libData, sockets, length)) return LIBRARY_FUNCTION_ERROR;
    SocketObject *data = (SocketObject *)libData->MTensor_getIntegerData(sockets);
    SocketObject *valid = malloc((length ? length : 1) * sizeof(SocketObject));
    if (!valid) return LIBRARY_MEMORY_ERROR;
    mint count = 0;
    for (size_t i = 0; i < length; i++)
        if (data[i].state == SOCKET_STATE_ALIVE && is_valid_socket((SOCKET)data[i].socket)) valid[count++] = data[i];
    mint dims[2] = {count, 6};
    MTensor validSockets;
    if (libData->MTensor_new(MType_Integer, 2, dims, &validSockets)) { free(valid); return LIBRARY_MEMORY_ERROR; }
    memcpy(libData->MTensor_getIntegerData(validSockets), valid, count * sizeof(SocketObject));
    free(valid);
    MArgument_setMTensor(Res, validSockets);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketConnectedQ(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketConnectedQ: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[0]);
    if (!socketObject) return LIBRARY_FUNCTION_ERROR;
    SOCKET socketId = (SOCKET)socketObject->socket;

    if (!ISVALIDSOCKET(socketId)) {
        MArgument_setBoolean(Res, False);
        return LIBRARY_NO_ERROR;
    }

    bool wasNonBlocking = socketObject->mode == SOCKET_MODE_NONBLOCKING;
    if (!wasNonBlocking) {
        set_non_blocking_mode(socketId);
    }

    char dummy;
    int ret = recv(socketId, &dummy, 1, MSG_PEEK);
    int err = GETSOCKETERRNO();

    if (!wasNonBlocking) {
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


DLLEXPORT int socketsSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketsSelect: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    MTensor sockets = MArgument_getMTensor(Args[0]); // list of sockets
    SocketObject *socketArray = (SocketObject *)libData->MTensor_getIntegerData(sockets);
    mint length = MArgument_getInteger(Args[1]); // number of sockets
    mint timeout = MArgument_getInteger(Args[2]); // timeout in microseconds
    mint mode = MArgument_getInteger(Args[3]); // 1 - read, 2 - write

    if (!socket_objects_valid(libData, sockets, length)) return LIBRARY_FUNCTION_ERROR;
    int result;
    mint dims[2];
    fd_set fds;
    MTensor readySockets;

    SOCKET *socketIds = malloc(sizeof(SOCKET) * length);
    if (!socketIds) {
        return LIBRARY_FUNCTION_ERROR;
    }

    for (mint i = 0; i < length; i++) {
        socketIds[i] = (SOCKET)socketArray[i].socket;
    }

    FD_ZERO(&fds);
    SOCKET maxfd = fill_fd_set_from_array(&fds, socketIds, length, 0);
    struct timeval tv = new_tv(timeout);

    switch (mode)
    {
    case 1:
        result = select((int)(maxfd + 1), &fds, NULL, NULL, &tv);
        break;
    case 2:
        result = select((int)(maxfd + 1), NULL, &fds, NULL, &tv);
        break;
    default:
        free(socketIds);
        return LIBRARY_FUNCTION_ERROR;
    }
    if (result >= 0) {
        dims[0] = result; dims[1] = 6;
        libData->MTensor_new(MType_Integer, 2, dims, &readySockets);
        SocketObject *out = (SocketObject *)libData->MTensor_getIntegerData(readySockets);
        mint j = 0;
        for (mint i = 0; i < length; i++)
            if (FD_ISSET(socketIds[i], &fds)) out[j++] = socketArray[i];
        free(socketIds);

        MArgument_setMTensor(Res, readySockets);
        return LIBRARY_NO_ERROR;
    } else {
        free(socketIds);
        return LIBRARY_FUNCTION_ERROR;
    }
}


DLLEXPORT int socketsPoll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketsPoll: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }
    MTensor socketsTensor = MArgument_getMTensor(Args[0]);
    mint length = MArgument_getInteger(Args[1]);
    mint timeout_us = MArgument_getInteger(Args[2]);
    mint eventsMask = MArgument_getInteger(Args[3]);

    if (!socket_objects_valid(libData, socketsTensor, length)) return LIBRARY_FUNCTION_ERROR;
    SocketObject *socketArray = (SocketObject *)libData->MTensor_getIntegerData(socketsTensor);

    if (length == 0) {
        MTensor emptyTensor;
        mint dims[2] = {0, 7};
        libData->MTensor_new(MType_Integer, 2, dims, &emptyTensor);
        MArgument_setMTensor(Res, emptyTensor);
        return LIBRARY_NO_ERROR;
    }

    int nativeEvents = convert_wl_to_native_events(eventsMask);

    POLL_FD *fds = (POLL_FD*)malloc(sizeof(POLL_FD) * length);
    if (!fds) {
        return LIBRARY_FUNCTION_ERROR;
    }

    for (mint i = 0; i < length; i++) {
        fds[i].fd = (SOCKET)socketArray[i].socket;
        fds[i].events = nativeEvents;
        fds[i].revents = 0;
    }

    int result = sockets_poll(fds, length, timeout_us);
    if (result < 0) {
        free(fds);
        return LIBRARY_FUNCTION_ERROR;
    }

    if (result == 0) {
        free(fds);
        mint dims[2] = {0, 7};
        MTensor emptyTensor;
        libData->MTensor_new(MType_Integer, 2, dims, &emptyTensor);
        MArgument_setMTensor(Res, emptyTensor);
        return LIBRARY_NO_ERROR;
    }

    mint dims[2] = {result, 7};
    MTensor resultTensor;
    libData->MTensor_new(MType_Integer, 2, dims, &resultTensor);
    mint *resultData = libData->MTensor_getIntegerData(resultTensor);

    int idx = 0;
    for (mint i = 0; i < length && idx < result; i++) {
        if (fds[i].revents != 0) {
            memcpy(resultData + idx * 7, &socketArray[i], sizeof(SocketObject));
            resultData[idx * 7 + 6] = convert_native_to_wl_events(fds[i].revents);
            idx++;
        }
    }

    free(fds);
    MArgument_setMTensor(Res, resultTensor);
    return LIBRARY_NO_ERROR;
}
