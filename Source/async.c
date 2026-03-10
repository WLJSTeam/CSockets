#include "async.h"

void pushTensor(WolframLibraryData libData, mint taskId, SOCKET *sockets) {

}

void socketsSelectTask(mint taskId, void *taskArgs) {
    SocketsSelectArgs socketsSelectTaskArgs = (SocketsSelectArgs)taskArgs;
    WolframLibraryData libData = socketsSelectTaskArgs->libData;
    SOCKET *sockets = socketsSelectTaskArgs->sockets;
    size_t length = socketsSelectTaskArgs->length;
    mint timeout = socketsSelectTaskArgs->timeout;

    SOCKET socketId;
    SOCKET maxFd = 0;

    struct timeval tv = new_tv(timeout);

    fd_set readfd;
    FD_ZERO(&readfd);

    for (size_t i = 0; i < length; i++) {
        socketId = sockets[i];
        if (socketId > maxFd) maxFd = socketId;
        FD_SET(socketId, &readfd);
    }

    int result = select((int)(maxFd + 1), &readfd, NULL, NULL, &tv);
    if (result >= 0) {
        mint len = (mint)result;
        MTensor readySocketsTensor;
        libData->MTensor_new(MType_Integer, 1, &len, &readySocketsTensor);
        mint *readySockets = libData->MTensor_getIntegerData(readySocketsTensor);

        filterFdset(&readfd, sockets, readySockets, length);

        DataStore dataStore;
        libData->ioLibraryFunctions->createDataStore();
        libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readySocketsTensor);
        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "socketsSelectTask", dataStore);
        libData->MTensor_free(readySocketsTensor);
    }

    free(sockets);
}

DLLEXPORT int socketsSelectAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    MTensor sockets = MArgument_getMTensor(Args[0]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets
    int timeout = (int)MArgument_getInteger(Args[2]); // timeout in microseconds

    SOCKET *socketIds = malloc(length * sizeof(SOCKET));

    mint *socketsData = libData->MTensor_getIntegerData(sockets);
    for(size_t i = 0; i < length; i++) {
        socketIds[i] = (SOCKET)socketsData[i];
    }

    SocketsSelectArgs taskArgs = malloc(sizeof(struct SocketsSelectArgs_st));

    taskArgs->libData = libData;
    taskArgs->sockets = socketIds;
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
    mint *readySockets;
    size_t j;
    MTensor readySocketsTensor;
    struct timeval tv;
    mint len;
    DataStore dataStore;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        length = socketList->length;
        sockets = socketList->sockets;

        FD_ZERO(&readfd);
        maxfd = slistFdset(socketList, &readfd, 0);
        tv = new_tv(timeout);

        int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
        if (result >= 0) {
            len = (mint)result;
            libData->MTensor_new(MType_Integer, 1, &len, &readySocketsTensor);
            readySockets = libData->MTensor_getIntegerData(readySocketsTensor);

            filterFdset(&readfd, sockets, readySockets, length);

            dataStore = libData->ioLibraryFunctions->createDataStore();
            libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readySocketsTensor);
            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "socketsSelectLoopTask", dataStore);
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
    SOCKET interrupter = args->interrupter;
    BYTE *buffer = args->buffer;
    int bufferSize = args->bufferSize;
    mint timeout = args->timeout;

    fd_set readfd;
    SOCKET *sockets;
    SOCKET maxfd;
    SOCKET socketId;
    int length;
    mint *readySockets;
    size_t j;
    MTensor readySocketsTensor;
    struct timeval tv;
    mint len;
    DataStore dataStore;
    int result;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        tv.tv_sec  = timeout / 1000000;
        tv.tv_usec = timeout % 1000000;

        FD_ZERO(&readfd);

        maxfd = interrupter;
        FD_SET(interrupter, &readfd);

        maxfd = slistFdset(acceptSockets, &readfd, maxfd);
        maxfd = slistFdset(recvSockets, &readfd, maxfd);
        maxfd = slistFdset(recvFromSockets, &readfd, maxfd);

        int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
        if (result >= 0) {
            if (FD_ISSET(interrupter, &readfd)) {
                result = recv(interrupter, (char *)buffer, bufferSize, 0);
                if (result > 0) {

                }
            }
        }
    }

}

DLLEXPORT int createServerLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList acceptSockets = (SocketList)MArgument_getInteger(Args[0]);
    SocketList recvSockets = (SocketList)MArgument_getInteger(Args[1]);
    SocketList recvFromSockets = (SocketList)MArgument_getInteger(Args[2]);
    SOCKET interrupter = (SOCKET)MArgument_getInteger(Args[3]);
    BYTE *buffer = (char *)MArgument_getInteger(Args[4]);
    int bufferSize = (int)MArgument_getInteger(Args[5]);
    mint timeout = MArgument_getInteger(Args[6]);

    ServerLoopArgs serverLoopArgs = malloc(sizeof(struct ServerLoopArgs_st));
    serverLoopArgs->libData = libData;
    serverLoopArgs->acceptSockets = acceptSockets;
    serverLoopArgs->recvSockets = recvSockets;
    serverLoopArgs->recvFromSockets = recvFromSockets;
    serverLoopArgs->interrupter = interrupter;
    serverLoopArgs->buffer = buffer;
    serverLoopArgs->bufferSize = bufferSize;
    serverLoopArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(serverLoop, (void *)serverLoopArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}