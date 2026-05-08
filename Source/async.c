#include "async.h"

void socketsSelectTask(mint taskId, void *taskArgs) {
    SocketsSelectArgs socketsSelectTaskArgs = (SocketsSelectArgs)taskArgs;
    WolframLibraryData libData = socketsSelectTaskArgs->libData;
    SOCKET *sockets = socketsSelectTaskArgs->sockets;
    size_t length = socketsSelectTaskArgs->length;
    mint timeout = socketsSelectTaskArgs->timeout;

    SOCKET socketId;
    SOCKET maxfd;
    MTensor readySockets;
    mint dims;
    struct timeval tv = new_tv(timeout);

    fd_set readfd;
    FD_ZERO(&readfd);
    maxfd = fillFdsetFromArray(&readfd, sockets, length, 0);

    int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
    if (result >= 0) {
        mint dims = (mint)result;
        libData->MTensor_new(MType_Integer, 1, &dims, &readySockets);

        filterFdsetToTensor(libData, &readfd, sockets, readySockets, length);

        DataStore dataStore;
        libData->ioLibraryFunctions->createDataStore();
        libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readySockets);
        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "ReadySockets", dataStore);
        libData->MTensor_free(readySockets);
    }

    free(sockets);
}

DLLEXPORT int socketsSelectAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    MTensor socketIds = MArgument_getMTensor(Args[0]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets
    int timeout = (int)MArgument_getInteger(Args[2]); // timeout in microseconds

    SOCKET *sockets = malloc(length * sizeof(SOCKET));
    copyTensorToSocketArray(libData, socketIds, sockets, length);

    SocketsSelectArgs taskArgs = malloc(sizeof(struct SocketsSelectArgs_st));

    taskArgs->libData = libData;
    taskArgs->sockets = sockets;
    taskArgs->length = length;
    taskArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsSelectTask, (void *)taskArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

void socketsSelectLoop(mint taskId, void *taskArgs) {
    SocketsSelectLoopArgs args = (SocketsSelectLoopArgs)taskArgs;

    WolframLibraryData libData = args->libData;
    SocketList socketList = args->socketList;
    mint timeout = args->timeout;

    fd_set readfd;
    SOCKET *sockets;
    SOCKET maxfd;
    SOCKET socketId;
    int length;
    int result;
    MTensor readyTensor;
    struct timeval tv;
    mint dims;
    DataStore dataStore;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        length = socketList->length;
        sockets = socketList->sockets;

        FD_ZERO(&readfd);
        maxfd = fillFdsetFromArray(&readfd, sockets, length, 0);
        tv = new_tv(timeout);

        result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
        if (result >= 0) {
            dims = (mint)result;
            libData->MTensor_new(MType_Integer, 1, &dims, &readyTensor);

            filterFdsetToTensor(libData, &readfd, sockets, readyTensor, length);

            dataStore = libData->ioLibraryFunctions->createDataStore();
            libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readyTensor);
            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "ReadySockets", dataStore);
            printf("raiseAsyncEvent completed\n");
        }
    }

    free(taskArgs);
}

DLLEXPORT int createSocketsSelectLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]); // socket list struct
    mint timeout = MArgument_getInteger(Args[1]);

    SocketsSelectLoopArgs taskArgs = malloc(sizeof(struct SocketsSelectLoopArgs_st));

    taskArgs->libData = libData;
    taskArgs->socketList = socketList;
    taskArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsSelectLoop, (void *)taskArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}



void serverLoop(mint taskId, void *taskArgs) {
    ServerLoopArgs args = (ServerLoopArgs)taskArgs;

    WolframLibraryData libData = args->libData;

    SocketList acceptSockets = args->acceptSockets;
    SocketList recvSockets = args->recvSockets;

    SocketList recvFromSockets = args->recvFromSockets;
    AddressInfoList recvFromAddrInfos = args->recvFromAddrInfos;

    SOCKET interrupter = args->interrupter;

    BYTE *buffer = args->buffer;
    mint bufferSize = args->bufferSize;

    mint timeout = args->timeout;

    fd_set readfd;
    SOCKET *sockets;
    mint length;
    SOCKET maxfd;
    SOCKET socketId;
    SOCKET clientId;
    mint *readySockets;
    size_t j;
    MTensor readySocketsTensor;
    struct timeval tv;
    mint len;
    DataStore dataStore;
    int result;
    struct addrinfo *addressInfo;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        tv = new_tv(timeout);

        FD_ZERO(&readfd);
        maxfd = interrupter;
        FD_SET(interrupter, &readfd);

        maxfd = fill_fd_set_from_array(&readfd, acceptSockets->sockets, acceptSockets->length, maxfd);
        maxfd = fill_fd_set_from_array(&readfd, recvSockets->sockets, recvSockets->length, maxfd);
        maxfd = fill_fd_set_from_array(&readfd, recvFromSockets->sockets, recvFromSockets->length, maxfd);

        int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
        if (result >= 0) {
            if (FD_ISSET(interrupter, &readfd)) {
                result = recv(interrupter, (char *)buffer, bufferSize, 0);
                if (result > 0) {

                } else {

                }
            }

            length = acceptSockets->length;
            sockets = acceptSockets->sockets;
            for (mint i = 0; i < length; i++) {
                socketId = sockets[i];
                if (FD_ISSET(socketId, &readfd)) {
                    clientId = accept(socketId, NULL, NULL);
                    socket_list_add(recvSockets, clientId);
                    dataStore = libData->ioLibraryFunctions->createDataStore();
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)clientId);
                    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Accept", dataStore);
                }
            }

            length = recvSockets->length;
            sockets = recvSockets->sockets;
            for (mint i = 0; i < length; i++) {
                socketId = sockets[i];
                if (FD_ISSET(socketId, &readfd)) {
                    result = recv(socketId, buffer,bufferSize, 0);
                    if (result > 0) {
                        dataStore = libData->ioLibraryFunctions->createDataStore();
                        libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)clientId);
                        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Recv", dataStore);
                    }
                }
            }

            length = recvFromSockets->length;
            sockets = recvFromSockets->sockets;
            for (mint i = 0; i < length; i++) {
                socketId = sockets[i];
                if (FD_ISSET(socketId, &readfd)) {
                    addressInfo = recvFromAddrInfos->adrrinfos[i];
                    result = recvfrom(socketId, buffer, bufferSize, 0, addressInfo->ai_addr, &addressInfo->ai_addrlen);
                    if (result > 0) {
                        mint dims = (mint)result;
                        dataStore = libData->ioLibraryFunctions->createDataStore();
                        libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)clientId);
                        libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)(uintptr_t)addressInfo);
                        MNumericArray numericArray;
                        libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &dims, &numericArray);
                        BYTE *numericArrayData = libData->numericarrayLibraryFunctions->MNumericArray_getData(numericArray);
                        memcpy(numericArrayData, buffer, result);
                        libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, numericArray);
                        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "RecvFrom", dataStore);
                    }
                }
            }
        }
    }
}

DLLEXPORT int createServerLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList acceptSockets = (SocketList)MArgument_getInteger(Args[0]);
    SocketList recvSockets = (SocketList)MArgument_getInteger(Args[1]);
    SocketList recvFromSockets = (SocketList)MArgument_getInteger(Args[2]);
    AddressInfoList recvFromAddrInfos = (AddressInfoList)MArgument_getInteger(Args[3]);
    SOCKET interrupter = (SOCKET)MArgument_getInteger(Args[4]);
    BYTE *buffer = (BYTE *)MArgument_getInteger(Args[5]);
    mint bufferSize = MArgument_getInteger(Args[6]);
    mint timeout = MArgument_getInteger(Args[7]);

    ServerLoopArgs serverLoopArgs = malloc(sizeof(struct ServerLoopArgs_st));
    serverLoopArgs->libData = libData;
    serverLoopArgs->acceptSockets = acceptSockets;
    serverLoopArgs->recvSockets = recvSockets;
    serverLoopArgs->recvFromSockets = recvFromSockets;
    serverLoopArgs->recvFromAddrInfos = recvFromAddrInfos;
    serverLoopArgs->interrupter = interrupter;
    serverLoopArgs->buffer = buffer;
    serverLoopArgs->bufferSize = bufferSize;
    serverLoopArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(serverLoop, (void *)serverLoopArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}