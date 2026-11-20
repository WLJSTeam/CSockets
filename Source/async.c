#include "async.h"


static void socketsPollLoop(mint taskId, void *taskArgs)
{
    SocketsPollArgs args = taskArgs;
    WolframLibraryData libData = args->libData;
    SocketList socketList = args->socketList;

    POLL_FD *fds = NULL;
    size_t length = 0;

    bool needRefresh = true;
    bool needPrune = false;
    bool failed = false;

    int nativeEvents = convert_wl_to_native_events(args->eventsMask);
    BYTE buffer[65536];

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId)) {
        if (needPrune) {
            socket_list_prune(socketList);
            needPrune = false;
            needRefresh = true;
        }

        if (length != socketList->length) {
            needRefresh = true;
        }

        if (needRefresh) {
            size_t newLength = socketList->length;
            size_t maxLength = SIZE_MAX / sizeof(POLL_FD);

            if (newLength > maxLength || newLength > INT_MAX) {
                failed = true;
                break;
            }

            if (newLength != length) {
                POLL_FD *newFds = NULL;

                if (newLength > 0) {
                    newFds = realloc(fds, newLength * sizeof(POLL_FD));

                    if (!newFds) {
                        failed = true;
                        break;
                    }
                } else {
                    free(fds);
                }

                fds = newFds;
                length = newLength;
            }

            for (size_t i = 0; i < length; i++) {
                fds[i].fd = socketList->sockets[i];
                fds[i].events = nativeEvents;

                if (socketList->roles[i] == SOCKET_ROLE_UNDEFINED) {
                    fds[i].events = 0;
                }
            }

            needRefresh = false;
        }

        for (size_t i = 0; i < length; i++) {
            fds[i].revents = 0;
        }

        int count = sockets_poll(fds, (mint)length, args->timeout);
        int nativeError = count < 0 ? GETSOCKETERRNO() : 0;

        if (count < 0) {
            for (size_t i = 0; i < length; i++) {
                int socketType;
                socklen_t typeLength = sizeof(socketType);
                int status = getsockopt(fds[i].fd, SOL_SOCKET, SO_TYPE, (char *)&socketType, &typeLength);

                if (status == SOCKET_ERROR) {
                    DataStore store = libData->ioLibraryFunctions->createDataStore();

                    if (store) {
                        libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)fds[i].fd);
                        libData->ioLibraryFunctions->DataStore_addInteger(store, nativeError);
                        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", store);
                    }

                    socketList->sockets[i] = INVALID_SOCKET;
                    needPrune = true;
                }
            }

            if (needPrune) {
                continue;
            }

            DataStore store = libData->ioLibraryFunctions->createDataStore();

            if (store) {
                libData->ioLibraryFunctions->DataStore_addInteger(store, -1);
                libData->ioLibraryFunctions->DataStore_addInteger(store, nativeError);
                libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", store);
            }

            break;
        }

        for (size_t i = 0; i < length; i++) {
            SOCKET socketId = fds[i].fd;
            SOCKET_ROLE role = socketList->roles[i];
            mint mask = convert_native_to_wl_events(fds[i].revents);

            if (mask == 0 || role == SOCKET_ROLE_UNDEFINED) {
                continue;
            }

            char *event = NULL;
            int error = 0;
            bool removeSocket = false;
            SOCKET acceptedSocket = INVALID_SOCKET;
            int received = -1;
            MNumericArray bytes = NULL;
            struct sockaddr_storage address = {0};
            char *endpoint = NULL;
            int socketType = 0;
            socklen_t typeLength = sizeof(socketType);
            int status = getsockopt(socketId, SOL_SOCKET, SO_TYPE, (char *)&socketType, &typeLength);
            bool readable = (mask & WL_POLLIN) != 0;
            bool invalid = (mask & WL_POLLNVAL) != 0;

            if (invalid || status == SOCKET_ERROR) {
                event = "Error";
                error = invalid ? (int)mask : GETSOCKETERRNO();
                removeSocket = true;
            } else if (readable) {
                if (role == SOCKET_ROLE_BINDED && socketType == SOCK_STREAM) {
                    acceptedSocket = accept(socketId, NULL, NULL);
                    bool valid = ISVALIDSOCKET(acceptedSocket);

                    if (valid) {
                        set_nonblocking_mode(acceptedSocket);
                        bool added = socket_list_add(socketList, acceptedSocket, SOCKET_ROLE_ACCEPTED);

                        if (added) {
                            needRefresh = true;
                            event = "Accepted";
                        } else {
                            CLOSESOCKET(acceptedSocket);
                            event = "Error";
                            error = LIBRARY_MEMORY_ERROR;
                        }
                    } else {
                        error = GETSOCKETERRNO();
                        bool pending = is_would_block_err(error);

                        if (!pending) {
                            event = "Error";
                        }
                    }
                } else {
                    if (socketType == SOCK_DGRAM) {
                        socklen_t addressLength = sizeof(address);
                        received = recvfrom(socketId, (char *)buffer, sizeof(buffer), 0,
                            (struct sockaddr *)&address, &addressLength);
                    } else {
                        received = recv(socketId, (char *)buffer, sizeof(buffer), 0);
                    }

                    if (received > 0 || (received == 0 && socketType == SOCK_DGRAM)) {
                        mint size = received;
                        status = libData->numericarrayLibraryFunctions->MNumericArray_new(
                            MNumericArray_Type_UBit8, 1, &size, &bytes);

                        if (status != LIBRARY_NO_ERROR) {
                            failed = true;
                            break;
                        }

                        if (received > 0) {
                            BYTE *data = libData->numericarrayLibraryFunctions->MNumericArray_getData(bytes);
                            memcpy(data, buffer, (size_t)received);
                        }

                        event = "Received";

                        if (socketType == SOCK_DGRAM) {
                            endpoint = sockaddr_storage_to_string(address);
                            event = "ReceivedFrom";

                            if (!endpoint) {
                                libData->numericarrayLibraryFunctions->MNumericArray_free(bytes);
                                bytes = NULL;
                                event = "Error";
                                error = LIBRARY_FUNCTION_ERROR;
                            }
                        }
                    } else if (received == 0) {
                        event = "Closed";
                        removeSocket = true;
                    } else {
                        error = GETSOCKETERRNO();
                        bool pending = is_would_block_err(error);

                        if (!pending) {
                            event = "Error";
                            removeSocket = true;
                        }
                    }
                }
            } else {
                bool socketError = (mask & WL_POLLERR) != 0;
                bool hangup = (mask & WL_POLLHUP) != 0;

                if (socketError || hangup) {
                    event = socketError ? "Error" : "Closed";
                    error = (int)mask;
                    removeSocket = true;
                }
            }

            if (removeSocket) {
                if (!invalid) {
                    CLOSESOCKET(socketId);
                }

                socketList->sockets[i] = INVALID_SOCKET;
                needPrune = true;
            }

            if (!event) {
                continue;
            }

            DataStore store = libData->ioLibraryFunctions->createDataStore();

            if (!store) {
                if (bytes) {
                    libData->numericarrayLibraryFunctions->MNumericArray_free(bytes);
                }

                failed = true;
                break;
            }

            libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);

            if (acceptedSocket != INVALID_SOCKET && error == 0) {
                libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)acceptedSocket);
            } else if (bytes) {
                if (endpoint) {
                    libData->ioLibraryFunctions->DataStore_addString(store, endpoint);
                }

                libData->ioLibraryFunctions->DataStore_addMNumericArray(store, bytes);
            } else if (error != 0) {
                libData->ioLibraryFunctions->DataStore_addInteger(store, error);
            }

            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, event, store);
        }

        if (failed) {
            break;
        }
    }

    if (failed) {
        DataStore store = libData->ioLibraryFunctions->createDataStore();

        if (store) {
            libData->ioLibraryFunctions->DataStore_addInteger(store, -1);
            libData->ioLibraryFunctions->DataStore_addInteger(store, LIBRARY_MEMORY_ERROR);
            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", store);
        }
    }

    free(fds);
    free(args);
}


DLLEXPORT int createSocketsPollLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("createSocketsPollLoop: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);
    mint timeout = MArgument_getInteger(Args[1]);
    mint eventsMask = MArgument_getInteger(Args[2]);

    if (!list || timeout < -1) {
        libData->Message("createSocketsPollLoop: invalid socket list or timeout");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketsPollArgs args = calloc(1, sizeof(struct SocketsPollArgs_st));

    if (!args) {
        libData->Message("createSocketsPollLoop: failed to allocate task arguments");
        return LIBRARY_MEMORY_ERROR;
    }

    args->libData = libData;
    args->socketList = list;
    args->eventsMask = eventsMask;
    args->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsPollLoop, args);

    if (taskId <= 0) {
        libData->Message("createSocketsPollLoop: failed to create asynchronous task");
        free(args);
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}
