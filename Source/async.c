#include "async.h"


void socketsSelectTask(mint taskId, void *taskArgs)
{
    SocketsSelectArgs socketsSelectTaskArgs = (SocketsSelectArgs)taskArgs;
    WolframLibraryData libData = socketsSelectTaskArgs->libData;
    SOCKET *sockets = socketsSelectTaskArgs->sockets;
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
        mint readyCount = (mint)result;
        libData->MTensor_new(MType_Integer, 1, &readyCount, &readySockets);

        filter_fd_set_to_tensor(libData, &readfd, sockets, readySockets, length);

        DataStore dataStore = libData->ioLibraryFunctions->createDataStore();
        libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readySockets);
        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Selected", dataStore);
        libData->MTensor_free(readySockets);
    }

    free(sockets);
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

    copy_tensor_to_socket_array(libData, socketIds, sockets, length);

    SocketsSelectArgs taskArgs = malloc(sizeof(struct SocketsSelectArgs_st));
    if (!taskArgs) {
        free(sockets);
        return LIBRARY_FUNCTION_ERROR;
    }

    taskArgs->libData = libData;
    taskArgs->sockets = sockets;
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

                if (wl_revents & (WL_POLLERR | WL_POLLHUP | WL_POLLNVAL)) {
                    CLOSESOCKET(socketId);
                    socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                    socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                    needPrune = True;

                    dataStore = libData->ioLibraryFunctions->createDataStore();
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketId);
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketType);
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)wl_revents);
                    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", dataStore);

                    continue;
                }

                if (wl_revents & WL_POLLIN) {
                    dataStore = libData->ioLibraryFunctions->createDataStore();
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketId);
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketType);

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

                            if (!socket_list_add(socketList, acceptedSocketObject)) {
                                CLOSESOCKET(acceptedSocketId);
                                continue;
                            }

                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)acceptedSocketId);
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, TCP_ACCEPTED);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Accepted", dataStore);
                        } else {
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

                            libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, byteArray);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Received", dataStore);
                        } else if (recvResult == 0) {
                            socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                            socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                            socketList->pollfds[i].fd = INVALID_SOCKET;
                            needPrune = True;

                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketId);
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, socketType);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", dataStore);
                        } else {
                            int err = GETSOCKETERRNO();

                            if (is_would_block_err(err)) {
                                continue;
                            }

                            socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                            socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                            socketList->pollfds[i].fd = INVALID_SOCKET;
                            needPrune = True;

                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, err);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", dataStore);
                        }
                    }

                    else if (socketType == UDP_SERVER || socketType == UDP_CLIENT) {
                        struct sockaddr_storage remoteAddr;
                        socklen_t remoteAddrLen = sizeof(remoteAddr);

                        int recvFromResult = recvfrom(socketId, buffer, bufferSize, 0, (struct sockaddr*)&remoteAddr, &remoteAddrLen);
                        if (recvFromResult >= 0) {
                            char host[INET6_ADDRSTRLEN];
                            unsigned short port;

                            if (!socket_address_to_host(&remoteAddr, host, sizeof(host), &port)) {
                                continue;
                            }

                            const mint dims = (mint)recvFromResult;

                            if (recvFromResult > 0) {
                                libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &dims, &byteArray);

                                BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
                                memcpy(array, buffer, recvFromResult);

                                libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, byteArray);
                            } else {
                                libData->ioLibraryFunctions->DataStore_addInteger(dataStore, 0);
                            }

                            libData->ioLibraryFunctions->DataStore_addString(dataStore, host);
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)port);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "ReceivedFrom", dataStore);
                        } else if (recvFromResult == 0) {
                            socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                            socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                            socketList->pollfds[i].fd = INVALID_SOCKET;
                            needPrune = True;

                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketId);
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, socketType);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", dataStore);
                        } else {
                            int err = GETSOCKETERRNO();

                            if (is_would_block_err(err)) {
                                continue;
                            }

                            socketList->sockets[i].socket = (int64_t)INVALID_SOCKET;
                            socketList->sockets[i].state = (int64_t)SOCKET_STATE_CLOSED;
                            socketList->pollfds[i].fd = INVALID_SOCKET;
                            needPrune = True;

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