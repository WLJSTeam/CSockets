#include "async.h"


/* Poll in bounded slices so task removal and list deletion can stop a wait.
 * A loop only reports readiness; WL owns accept/receive/close and metadata.
 * "Polled" payload: one rank-2 integer tensor of {socketId, eventMask} rows.
 * "Error" payload: one integer (native error or LibraryLink error code).
 */
static void socketsPollTask(mint taskId, void *taskArgs)
{
    SocketsPollArgs args = taskArgs;
    WolframLibraryData libData = args->libData;
    bool repeat = args->list != NULL;
    mint remaining = args->timeout;
    do {
        SOCKET *sockets = args->sockets;
        mint length = args->length;
        int status = LIBRARY_NO_ERROR;
        if (repeat) {
            status = socket_list_snapshot(args->list, &sockets, &length);
            if (status) break; /* The owner may have deleted the list. */
        }
        POLL_FD *fds = length ? calloc((size_t)length, sizeof(POLL_FD)) : NULL;
        if (length && !fds) status = LIBRARY_MEMORY_ERROR;
        if (!status) {
            for (mint i = 0; i < length; i++) {
                fds[i].fd = sockets[i];
                fds[i].events = convert_wl_to_native_events(args->eventsMask);
            }
        }
        if (repeat) free(sockets);
        if (status) {
            free(fds);
            break;
        }

        mint interval = remaining < 0 || remaining > 50000 ? 50000 : remaining;
        int count = sockets_poll(fds, length, interval);
        int nativeError = count < 0 ? GETSOCKETERRNO() : 0;
        if (!libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId)) {
            free(fds);
            break;
        }

        if (count > 0 || (!repeat && count == 0 && remaining == interval)) {
            mint dims[2] = {count, 2};
            MTensor events;
            status = libData->MTensor_new(MType_Integer, 2, dims, &events);
            if (!status) {
                mint *data = libData->MTensor_getIntegerData(events);
                mint row = 0;
                for (mint i = 0; i < length; i++) {
                    if (fds[i].revents) {
                        data[2 * row] = (mint)fds[i].fd;
                        data[2 * row + 1] = convert_native_to_wl_events(fds[i].revents);
                        row++;
                    }
                }
                DataStore store = libData->ioLibraryFunctions->createDataStore();
                if (store) {
                    libData->ioLibraryFunctions->DataStore_addMTensor(store, events);
                    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Polled", store);
                } else {
                    libData->MTensor_free(events);
                    status = LIBRARY_MEMORY_ERROR;
                }
            }
        }
        free(fds);
        if (count < 0 || status) {
            DataStore store = libData->ioLibraryFunctions->createDataStore();
            if (store) {
                libData->ioLibraryFunctions->DataStore_addInteger(store, count < 0 ? nativeError : status);
                libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", store);
            }
            break;
        }
        if (repeat) remaining = args->timeout;
        else {
            if (count > 0 || remaining == interval) break;
            if (remaining > 0) remaining -= interval;
        }
        /* Avoid flooding the event queue while WL processes a ready socket. */
        if (repeat && (count > 0 || interval == 0)) {
#ifdef _WIN32
            Sleep(1);
#else
            usleep(1000);
#endif
        }
    } while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId));

    if (repeat) socket_list_release(args->list);
    free(args->sockets);
    free(args);
}


DLLEXPORT int socketsPollAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) return LIBRARY_FUNCTION_ERROR;
    MTensor socketIds = MArgument_getMTensor(Args[0]);
    mint timeout = MArgument_getInteger(Args[1]);
    mint eventsMask = MArgument_getInteger(Args[2]);
    if (libData->MTensor_getRank(socketIds) != 1 || timeout < -1) return LIBRARY_FUNCTION_ERROR;
    mint length = libData->MTensor_getFlattenedLength(socketIds);
    if ((size_t)length > SIZE_MAX / sizeof(POLL_FD) || length > INT_MAX) return LIBRARY_MEMORY_ERROR;
    SocketsPollArgs args = calloc(1, sizeof(struct SocketsPollArgs_st));
    if (!args) return LIBRARY_MEMORY_ERROR;
    if (length) {
        args->sockets = malloc((size_t)length * sizeof(SOCKET));
        if (!args->sockets) { free(args); return LIBRARY_MEMORY_ERROR; }
        mint *data = libData->MTensor_getIntegerData(socketIds);
        for (mint i = 0; i < length; i++) args->sockets[i] = (SOCKET)data[i];
    }
    args->libData = libData;
    args->length = length;
    args->timeout = timeout;
    args->eventsMask = eventsMask;
    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsPollTask, args);
    if (taskId <= 0) { free(args->sockets); free(args); return LIBRARY_FUNCTION_ERROR; }
    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int createSocketsPollLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) return LIBRARY_FUNCTION_ERROR;
    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);
    mint timeout = MArgument_getInteger(Args[1]);
    mint eventsMask = MArgument_getInteger(Args[2]);
    if (timeout < -1 || !socket_list_retain(list)) return LIBRARY_FUNCTION_ERROR;
    SocketsPollArgs args = calloc(1, sizeof(struct SocketsPollArgs_st));
    if (!args) { socket_list_release(list); return LIBRARY_MEMORY_ERROR; }
    args->libData = libData;
    args->list = list;
    args->timeout = timeout;
    args->eventsMask = eventsMask;
    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsPollTask, args);
    if (taskId <= 0) { socket_list_release(list); free(args); return LIBRARY_FUNCTION_ERROR; }
    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}
