#include "socket.h"


DLLEXPORT int socketCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    int family = (int)MArgument_getInteger(Args[0]);   // family
    int socktype = (int)MArgument_getInteger(Args[1]); // sock type
    int protocol = (int)MArgument_getInteger(Args[2]); // protocol

    SOCKET createdSocket = socket(family, socktype, protocol);
    if (createdSocket == INVALID_SOCKET) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, createdSocket); // return socket id
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketClose(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = MArgument_getInteger(Args[0]);

    mint result = true;

    if (socketId > 0) {
        result = CLOSESOCKET(socketId);
    }

    if (result == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    struct addrinfo *addressInfo = (struct addrinfo*)(uintptr_t)MArgument_getInteger(Args[1]);

    if (addressInfo == NULL) {
        return LIBRARY_FUNCTION_ERROR;
    }

    if (socketId == INVALID_SOCKET) {
        return LIBRARY_FUNCTION_ERROR;
    }

    int iResult = bind(socketId, addressInfo->ai_addr, (int)addressInfo->ai_addrlen);
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);
    int optval = (int)MArgument_getInteger(Args[3]);

    int iResult = setsockopt(socketId, level, optname, (const char*)&optval, sizeof(optval));
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketGetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);

    int optval = 0;
    socklen_t optlen = sizeof(optval);

    int iResult = getsockopt(socketId, level, optname, (char*)&optval, &optlen);
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, optval);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    set_blocking_mode(socketId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetNonBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    set_non_blocking_mode(socketId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int backlog = (int)MArgument_getInteger(Args[1]);

    /*start waiting for clients*/
    int iResult = listen(socketId, backlog);
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    struct addrinfo *addressInfo = (struct addrinfo*)(uintptr_t)MArgument_getInteger(Args[1]);

    int iResult = connect(socketId, addressInfo->ai_addr, (int)addressInfo->ai_addrlen);
    if (iResult == SOCKET_ERROR) {
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketAccept(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    SOCKET acceptedSocketId = accept(socketId, NULL, NULL);

    if (acceptedSocketId == INVALID_SOCKET) {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, acceptedSocketId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    BYTE *buffer = (BYTE *)(uintptr_t)MArgument_getInteger(Args[1]);
    size_t bufferSize = (size_t)MArgument_getInteger(Args[2]);

    int result = recv(socketId, buffer, bufferSize, 0);
    if (result >= 0) {
        mint len = (mint)result;
        MNumericArray byteArray;
        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &len, &byteArray);

        if (result > 0) {
            BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
            memcpy(array, buffer, result);
        }

        MArgument_setMNumericArray(Res, byteArray);
        return LIBRARY_NO_ERROR;
    }

    char errorMsg[32];
    snprintf(errorMsg, sizeof(errorMsg), "socketrecverror%d", GETSOCKETERRNO());
    libData->Message(errorMsg);
    return LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET client = (SOCKET)MArgument_getInteger(Args[0]);
    uintptr_t addressInfoPtr = (uintptr_t)MArgument_getInteger(Args[1]); // address pointer as integer
    struct addrinfo *addressInfo = (struct addrinfo*)addressInfoPtr;
    BYTE *buffer = (BYTE *)MArgument_getInteger(Args[2]);
    mint bufferSize = (mint)MArgument_getInteger(Args[3]);

    int result = recvfrom(client, buffer, bufferSize, 0, addressInfo->ai_addr, &(addressInfo->ai_addrlen));
    if (result >= 0) {
        mint len = (mint)result;
        MNumericArray byteArray;
        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &len, &byteArray);

        if (len > 0) {
            BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
            memcpy(array, buffer, result);
        }

        MArgument_setMNumericArray(Res, byteArray);
        return LIBRARY_NO_ERROR;
    }

    char errorMsg[32];
    snprintf(errorMsg, sizeof(errorMsg), "socketrecvfromerror:%d", GETSOCKETERRNO());
    libData->Message(errorMsg);
    return LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketSend(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = MArgument_getInteger(Args[0]);
    MNumericArray byteArray = MArgument_getMNumericArray(Args[1]);
    BYTE *data = (BYTE*)libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
    int length = MArgument_getInteger(Args[2]);

    int sentLength = send(socketId, (char*)data, length, 0);
    if (sentLength > 0) {
        libData->numericarrayLibraryFunctions->MNumericArray_disown(byteArray);
        MArgument_setInteger(Res, sentLength);
        return LIBRARY_NO_ERROR;
    }

    libData->numericarrayLibraryFunctions->MNumericArray_disown(byteArray);
    return LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketSendString(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = MArgument_getInteger(Args[0]);
    char *text = MArgument_getUTF8String(Args[1]);
    int length = MArgument_getInteger(Args[2]);

    int sentLength = send(socketId, text, length, 0);
    if (sentLength > 0) {
        libData->UTF8String_disown(text);
        MArgument_setInteger(Res, sentLength);
        return LIBRARY_NO_ERROR;
    }

    libData->UTF8String_disown(text);
    return LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketSendTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    char *host = MArgument_getUTF8String(Args[1]);
    unsigned short port = (unsigned short)MArgument_getInteger(Args[2]);

    MNumericArray byteArray = MArgument_getMNumericArray(Args[3]);
    BYTE *data = (BYTE *)libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
    mint length = MArgument_getInteger(Args[4]);

    struct sockaddr_storage address;
    socklen_t addressLength;

    if (!socket_address_from_host(host, port, &address, &addressLength))
    {
        libData->UTF8String_disown(host);
        libData->numericarrayLibraryFunctions->MNumericArray_disown(byteArray);
        return LIBRARY_FUNCTION_ERROR;
    }

    int sentLength = sendto(socketId, (const char *)data, (size_t)length, 0, (const struct sockaddr *)&address, addressLength);

    libData->UTF8String_disown(host);
    libData->numericarrayLibraryFunctions->MNumericArray_disown(byteArray);

    if (sentLength < 0)
    {
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSendStringTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    char *host = MArgument_getUTF8String(Args[1]);
    unsigned short port = (unsigned short)MArgument_getInteger(Args[2]);

    char *text = MArgument_getUTF8String(Args[3]);
    mint length = MArgument_getInteger(Args[4]);

    struct sockaddr_storage address;
    socklen_t addressLength;

    if (!socket_address_from_host(host, port, &address, &addressLength))
    {
        libData->UTF8String_disown(host);
        libData->UTF8String_disown(text);
        return LIBRARY_FUNCTION_ERROR;
    }

    int sentLength = sendto(socketId, text, (size_t)length, 0, (const struct sockaddr *)&address, addressLength);

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
    MTensor sockets = MArgument_getMTensor(Args[0]);       // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets

    mint *socketsData = (mint*)libData->MTensor_getIntegerData(sockets);
    SOCKET socketId;
    mint validCount = 0;
    int opt;
    int err;
    socklen_t len = sizeof(opt);

    for (size_t i = 0; i < length; i++) {
        socketId = (SOCKET)socketsData[i];

        if (is_valid_socket(socketId)) {
            socketsData[validCount] = (mint)socketId;
            validCount++;
        }
    }

    MTensor validSockets;
    libData->MTensor_new(MType_Integer, 1, &validCount, &validSockets);
    mint *validSocketsData = (mint*)libData->MTensor_getIntegerData(validSockets);

    for (mint i = 0; i < validCount; i++) {
        validSocketsData[i] = socketsData[i];
    }

    MArgument_setMTensor(Res, validSockets);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketIsConnected(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SOCKET sockedId = (SOCKET)MArgument_getInteger(Args[0]);

    if (!ISVALIDSOCKET(sockedId)) {
        MArgument_setBoolean(Res, False);
        return LIBRARY_NO_ERROR;
    }

    bool wasNonBlocking = is_non_blocking_mode(sockedId);
    if (!wasNonBlocking) {
        set_non_blocking_mode(sockedId);
    }

    char dummy;
    int ret = recv(sockedId, &dummy, 1, MSG_PEEK);
    int err = GETSOCKETERRNO();

    if (!wasNonBlocking) {
        set_blocking_mode(sockedId);
    }

    if (ret > 0) {
        MArgument_setBoolean(Res, True);
        return LIBRARY_NO_ERROR;
    }

    if (ret == 0) {
        MArgument_setBoolean(Res, False);
        return LIBRARY_NO_ERROR;
    }

#ifdef _WIN32
    if (err == WSAEWOULDBLOCK)
#else
    if (err == EAGAIN || err == EWOULDBLOCK)
#endif
    {
        MArgument_setBoolean(Res, True);
        return LIBRARY_NO_ERROR;
    }

    MArgument_setBoolean(Res, False);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketsSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    MTensor sockets = MArgument_getMTensor(Args[0]); // list of sockets
    mint *socketArray = libData->MTensor_getIntegerData(sockets);
    mint length = MArgument_getInteger(Args[1]); // number of sockets
    mint timeout = MArgument_getInteger(Args[2]); // timeout in microseconds
    mint mode = MArgument_getInteger(Args[3]); // 1 - read, 2 - write

    int err;
    SOCKET socketId;
    fd_set fds;
    MTensor readySockets;
    mint dims;

    SOCKET *socketIds = malloc(sizeof(SOCKET) * length);
    if (!socketIds) {
        return LIBRARY_FUNCTION_ERROR;
    }

    for (mint i = 0; i < length; i++) {
        socketIds[i] = (SOCKET)socketArray[i];
    }

    FD_ZERO(&fds);
    SOCKET maxfd = fill_fd_set_from_array(&fds, socketIds, length, 0);
    struct timeval tv = new_tv(timeout);

    int result;
    switch (mode)
    {
    case 1:
        result = select((int)(maxfd + 1), &fds, NULL, NULL, &tv);
        break;
    case 2:
        result = select((int)(maxfd + 1), NULL, &fds, NULL, &tv);
        break;
    default:
        return LIBRARY_FUNCTION_ERROR;
    }
    if (result >= 0) {
        dims = (mint)result;
        libData->MTensor_new(MType_Integer, 1, &dims, &readySockets);

        filter_fd_set_to_tensor(libData, &fds, socketIds, readySockets, result);
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
    MTensor socketsTensor = MArgument_getMTensor(Args[0]);
    mint length = MArgument_getInteger(Args[1]);
    mint timeout_us = MArgument_getInteger(Args[2]);
    mint eventsMask = MArgument_getInteger(Args[3]);

    mint *socketArray = libData->MTensor_getIntegerData(socketsTensor);

    if (length == 0) {
        MTensor emptyTensor;
        mint dims[2] = {0, 2};
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
        fds[i].fd = (SOCKET)socketArray[i];
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
        mint dims[2] = {0, 2};
        MTensor emptyTensor;
        libData->MTensor_new(MType_Integer, 2, dims, &emptyTensor);
        MArgument_setMTensor(Res, emptyTensor);
        return LIBRARY_NO_ERROR;
    }

    mint dims[2] = {result, 2};
    MTensor resultTensor;
    libData->MTensor_new(MType_Integer, 2, dims, &resultTensor);
    mint *resultData = libData->MTensor_getIntegerData(resultTensor);

    int idx = 0;
    for (mint i = 0; i < length && idx < result; i++) {
        if (fds[i].revents != 0) {
            resultData[idx * 2 + 0] = (mint)fds[i].fd;
            resultData[idx * 2 + 1] = convert_native_to_wl_events(fds[i].revents);
            idx++;
        }
    }

    free(fds);
    MArgument_setMTensor(Res, resultTensor);
    return LIBRARY_NO_ERROR;
}