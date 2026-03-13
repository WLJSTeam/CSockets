#include "socket.h"

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

/*socketClose[socketId] -> successStatus*/
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

/*socketBind[socketId, addressInfoPtr] -> successStatus*/
DLLEXPORT int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]); // socket for binding
    uintptr_t addressInfoPtr = (uintptr_t)MArgument_getInteger(Args[1]); // address pointer as integer
    struct addrinfo *addressInfo = (struct addrinfo*)addressInfoPtr;

    bool successState = 0;

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

/*socketConnect[socketId, addressInfo] -> successStatus*/
DLLEXPORT int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    uintptr_t addressInfoPtr = (uintptr_t)MArgument_getInteger(Args[1]); // address pointer as integer
    struct addrinfo *addressInfo = (struct addrinfo*)addressInfoPtr;
    bool wait = (bool)MArgument_getBoolean(Args[2]); // wait for connection

    bool blockingMode = blockingModeQ(socketId);
    if (wait && !blockingMode) {
        setBlockingMode(socketId, true); // set blocking mode if needed
    }

    int iResult = connect(socketId, addressInfo->ai_addr, (int)addressInfo->ai_addrlen);
    if (iResult == SOCKET_ERROR) {
        if (wait && !blockingMode) {
            setBlockingMode(socketId, false);
        }
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
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, client);
    return LIBRARY_NO_ERROR;
}

/*socketRecv[socketId, bufferPtr, bufferLength] -> byteArray*/
DLLEXPORT int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET client = (SOCKET)MArgument_getInteger(Args[0]);
    BYTE *buffer = (BYTE *)(uintptr_t)MArgument_getInteger(Args[1]);
    size_t bufferSize = (size_t)MArgument_getInteger(Args[2]);

    lockGlobalMutex();
    int result = recv(client, buffer, bufferSize, 0);
    unlockGlobalMutex();

    if (result > 0) {
        mint len = (mint)result;
        MNumericArray byteArray;
        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &len, &byteArray);
        BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
        memcpy(array, buffer, result);
        MArgument_setMNumericArray(Res, byteArray);
        return LIBRARY_NO_ERROR;
    }

    char errorMsg[256];
    snprintf(errorMsg, sizeof(errorMsg), "Socket error: %d", GETSOCKETERRNO());
    libData->Message(errorMsg);
    return LIBRARY_FUNCTION_ERROR;
}

/*socketRecvFrom[socketId, addressInfoPtr, bufferPtr, bufferLength] -> byteArray (only UDP)*/
DLLEXPORT int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET client = (SOCKET)MArgument_getInteger(Args[0]);
    uintptr_t addressInfoPtr = (uintptr_t)MArgument_getInteger(Args[1]); // address pointer as integer
    struct addrinfo *addressInfo = (struct addrinfo*)addressInfoPtr;
    BYTE *buffer = (BYTE *)MArgument_getInteger(Args[2]);
    mint bufferSize = (mint)MArgument_getInteger(Args[3]);

    lockGlobalMutex();
    int result = recvfrom(client, buffer, bufferSize, 0, addressInfo->ai_addr, &(addressInfo->ai_addrlen));
    unlockGlobalMutex();

    if (result > 0) {
        mint dims = (mint)result;
        MNumericArray byteArray;
        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &dims, &byteArray);
        BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
        memcpy(array, buffer, result);

        MArgument_setMNumericArray(Res, byteArray);
        return LIBRARY_NO_ERROR;
    }

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

    return LIBRARY_FUNCTION_ERROR;
}

DLLEXPORT int socketSendTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    uintptr_t addressInfoPtr = (uintptr_t)MArgument_getInteger(Args[1]);
    struct addrinfo *addressInfo = (struct addrinfo*)addressInfoPtr;

    MNumericArray dataByteArray = MArgument_getMNumericArray(Args[2]);
    mint dataLength = MArgument_getInteger(Args[3]);

    if (addressInfo == NULL || dataLength <= 0) {
        return LIBRARY_FUNCTION_ERROR;
    }

    BYTE *data = (BYTE*)libData->numericarrayLibraryFunctions->MNumericArray_getData(dataByteArray);
    if (!data) {
        return LIBRARY_FUNCTION_ERROR;
    }

    lockGlobalMutex();
    int result = sendto(socketId, (const char*)data, dataLength, 0, addressInfo->ai_addr, addressInfo->ai_addrlen);
    unlockGlobalMutex();

    if (result > 0) {
        MArgument_setInteger(Res, result);
        return LIBRARY_NO_ERROR;
    }

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
    MTensor sockets = MArgument_getMTensor(Args[0]); // list of sockets
    mint *socketArray = libData->MTensor_getIntegerData(sockets);
    mint length = MArgument_getInteger(Args[1]); // number of sockets
    mint timeout = MArgument_getInteger(Args[2]); // timeout in microseconds

    int err;
    SOCKET socketId;
    fd_set readfd;
    MTensor readySockets;
    mint dims;

    SOCKET *socketIds = malloc(sizeof(SOCKET) * length);
    if (!socketIds) {
        return LIBRARY_FUNCTION_ERROR;
    }

    for (mint i = 0; i < length; i++) {
        socketIds[i] = (SOCKET)socketArray[i];
    }

    FD_ZERO(&readfd);
    SOCKET maxfd = fillFdsetFromArray(&readfd, socketIds, length, 0);
    struct timeval tv = new_tv(timeout);

    int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
    if (result >= 0) {
        dims = (mint)result;
        libData->MTensor_new(MType_Integer, 1, &dims, &readySockets);

        filterFdsetToTensor(libData, &readfd, socketIds, readySockets, result);
        free(socketIds);

        MArgument_setMTensor(Res, readySockets);
        return LIBRARY_NO_ERROR;
    } else {
        free(socketIds);
        return LIBRARY_FUNCTION_ERROR;
    }
}