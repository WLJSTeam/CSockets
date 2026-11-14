#include "async.h"
#include "address.h"


void socketsSelectTask(mint taskId, void *taskArgs)
{
    SocketsSelectArgs socketsSelectTaskArgs = (SocketsSelectArgs)taskArgs;
    WolframLibraryData libData = socketsSelectTaskArgs->libData;
    SOCKET *sockets = socketsSelectTaskArgs->sockets;
    SocketObject *objects = socketsSelectTaskArgs->objects;
    size_t length = socketsSelectTaskArgs->length;
    mint timeout = socketsSelectTaskArgs->timeout;

    SOCKET maxfd;
    MTensor readySockets;
    struct timeval tv = new_tv(timeout);

    fd_set readfd;
    FD_ZERO(&readfd);
    maxfd = fill_fd_set_from_array(&readfd, sockets, length, 0);

    int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
    if (result >= 0) {
        mint dims[2] = {result, 6};
        libData->MTensor_new(MType_Integer, 2, dims, &readySockets);
        SocketObject *out = (SocketObject *)libData->MTensor_getIntegerData(readySockets);
        mint j = 0;
        for (size_t i = 0; i < length; i++)
            if (FD_ISSET(sockets[i], &readfd)) out[j++] = objects[i];

        DataStore dataStore = libData->ioLibraryFunctions->createDataStore();
        libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readySockets);
        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Selected", dataStore);

    }

    free(sockets);
    free(objects);
    free(taskArgs);
}


DLLEXPORT int socketsSelectAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    MTensor socketIds = MArgument_getMTensor(Args[0]);     // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets
    int timeout = (int)MArgument_getInteger(Args[2]);      // timeout in microseconds

    SOCKET *sockets = malloc(length * sizeof(SOCKET));
    if (!sockets) {
        return LIBRARY_FUNCTION_ERROR;
    }

    if (!socket_objects_valid(libData, socketIds, length)) { free(sockets); return LIBRARY_FUNCTION_ERROR; }
    SocketObject *objects = malloc(length * sizeof(SocketObject));
    if (!objects) { free(sockets); return LIBRARY_MEMORY_ERROR; }
    memcpy(objects, libData->MTensor_getIntegerData(socketIds), length * sizeof(SocketObject));
    for (size_t i = 0; i < length; i++) sockets[i] = (SOCKET)objects[i].socket;

    SocketsSelectArgs taskArgs = malloc(sizeof(struct SocketsSelectArgs_st));
    if (!taskArgs) {
        free(objects);
        free(sockets);
        return LIBRARY_FUNCTION_ERROR;
    }

    taskArgs->libData = libData;
    taskArgs->sockets = sockets;
    taskArgs->objects = objects;
    taskArgs->length = length;
    taskArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsSelectTask, (void *)taskArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}


void socketsPollLoop(mint taskId, void *taskArgs)
{
    ServerLoopArgs args = (ServerLoopArgs)taskArgs;

    SocketList socketList = args->socketList;

    WolframLibraryData libData = args->libData;
    mint bufferSize = args->bufferSize;
    BYTE *buffer = malloc(bufferSize);
    if (!buffer) {
        free(taskArgs);
        return;
    }
    mint timeout = args->timeout;
    mint eventsMask = args->eventsMask;
    int nativeEvents = convert_wl_to_native_events(eventsMask);

    int result;
    SOCKET acceptedSocketId;
    MNumericArray byteArray;
    DataStore dataStore;
    bool needPrune = False;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        if (needPrune) {
            socket_list_prune(socketList);
            needPrune = False;
        }

        size_t length = socketList->length;

        for (size_t i = 0; i < length; i++) {
            socketList->pollfds[i].fd = (SOCKET)socketList->sockets[i].socket;
            socketList->pollfds[i].events = nativeEvents;
            socketList->pollfds[i].revents = 0;
        }

        result = sockets_poll(socketList->pollfds, length, timeout);
        if (result > 0) {
            for (size_t i = 0; i < length; i++) {
                mint wl_revents = convert_native_to_wl_events(socketList->pollfds[i].revents);
                SOCKET socketId = socketList->pollfds[i].fd;
                SOCKET_TYPE socketType = socket_list_socket_type(socketList->sockets[i]);
                SocketObject eventSocket = socketList->sockets[i];

                if (wl_revents & (WL_POLLERR | WL_POLLHUP | WL_POLLNVAL)) {
                    CLOSESOCKET(socketId);
                    socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                    socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                    needPrune = True;

                    dataStore = libData->ioLibraryFunctions->createDataStore();
                    eventSocket.state = SOCKET_STATE_CLOSED;
                    DataStore_addSocketObject(libData, dataStore, eventSocket);
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)wl_revents);
                    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", dataStore);

                    continue;
                }

                if (wl_revents & WL_POLLIN) {
                    dataStore = libData->ioLibraryFunctions->createDataStore();

                    if (socketType == TCP_SERVER) {
                        acceptedSocketId = accept(socketId, NULL, NULL);
                        if (ISVALIDSOCKET(acceptedSocketId)) {
                            SocketObject acceptedSocketObject = {
                                .socket = (int64_t)acceptedSocketId,
                                .protocol = (int64_t)SOCKET_PROTOCOL_TCP,
                                .type = (int64_t)SOCKET_TYPE_STREAM,
                                .role = (int64_t)SOCKET_ROLE_ACCEPTED,
                                .state = (int64_t)SOCKET_STATE_ALIVE,
                                .mode = socketList->sockets[i].mode
                            };

                            if (acceptedSocketObject.mode == SOCKET_MODE_NONBLOCKING) set_non_blocking_mode(acceptedSocketId);
                            else set_blocking_mode(acceptedSocketId);
                            if (!socket_list_add(socketList, acceptedSocketObject)) {
                                CLOSESOCKET(acceptedSocketId);
                                continue;
                            }

                            DataStore_addSocketObject(libData, dataStore, eventSocket);
                            DataStore_addSocketObject(libData, dataStore, acceptedSocketObject);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Accepted", dataStore);
                        } else {
                            DataStore_addSocketObject(libData, dataStore, eventSocket);
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, GETSOCKETERRNO());
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", dataStore);
                            continue;
                        }
                    }

                    else if (socketType == TCP_CLIENT || socketType == TCP_ACCEPTED) {
                        int recvResult = recv(socketId, buffer, bufferSize, 0);
                        if (recvResult > 0) {
                            const mint dims = (mint)recvResult;
                            libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &dims, &byteArray);

                            BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
                            memcpy(array, buffer, recvResult);

                            DataStore_addSocketObject(libData, dataStore, eventSocket);
                            libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, byteArray);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Received", dataStore);
                        } else if (recvResult == 0) {
                            CLOSESOCKET(socketId);
                            socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                            socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                            socketList->pollfds[i].fd = INVALID_SOCKET;
                            needPrune = True;

                            eventSocket.state = SOCKET_STATE_CLOSED;
                            DataStore_addSocketObject(libData, dataStore, eventSocket);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", dataStore);
                        } else {
                            int err = GETSOCKETERRNO();

                            if (is_would_block_err(err)) {
                                continue;
                            }

                            CLOSESOCKET(socketId);
                            socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                            socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                            socketList->pollfds[i].fd = INVALID_SOCKET;
                            needPrune = True;

                            eventSocket.state = SOCKET_STATE_CLOSED;
                            DataStore_addSocketObject(libData, dataStore, eventSocket);
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, err);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", dataStore);
                        }
                    }

                    else if (socketType == UDP_SERVER || socketType == UDP_CLIENT) {
                        struct sockaddr_storage remoteAddr;
                        socklen_t remoteAddrLen = sizeof(remoteAddr);

                        int recvFromResult = recvfrom(socketId, buffer, bufferSize, 0, (struct sockaddr*)&remoteAddr, &remoteAddrLen);
                        if (recvFromResult >= 0) {
                            DataStore_addSocketObject(libData, dataStore, eventSocket);
                            DataStore_addAddressStorage(libData, dataStore, &remoteAddr);

                            if (recvFromResult > 0) {
                                const mint dims = (mint)recvFromResult;
                                libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &dims, &byteArray);

                                BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
                                memcpy(array, buffer, recvFromResult);

                                libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, byteArray);
                            }

                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "ReceivedFrom", dataStore);
                        } else {
                            int err = GETSOCKETERRNO();

                            if (is_would_block_err(err)) {
                                continue;
                            }

                            CLOSESOCKET(socketId);
                            socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                            socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                            socketList->pollfds[i].fd = INVALID_SOCKET;
                            needPrune = True;

                            eventSocket.state = SOCKET_STATE_CLOSED;
                            DataStore_addSocketObject(libData, dataStore, eventSocket);
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, err);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", dataStore);
                        }
                    }
                }
            }
        }
    }

    free(buffer);
    free(taskArgs);
}


DLLEXPORT int createSocketsPollLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    mint bufferSize = MArgument_getInteger(Args[1]);
    mint timeout = MArgument_getInteger(Args[2]);
    mint eventsMask = MArgument_getInteger(Args[3]);

    ServerLoopArgs serverLoopArgs = malloc(sizeof(struct ServerLoopArgs_st));
    if (!serverLoopArgs) {
        return LIBRARY_FUNCTION_ERROR;
    }

    serverLoopArgs->libData = libData;
    serverLoopArgs->socketList = socketList;
    serverLoopArgs->bufferSize = bufferSize;
    serverLoopArgs->timeout = timeout;
    serverLoopArgs->eventsMask = eventsMask;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsPollLoop, (void *)serverLoopArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}