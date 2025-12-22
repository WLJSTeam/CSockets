#include "internal.h"

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

/*push list of sockets that ready for read*/
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