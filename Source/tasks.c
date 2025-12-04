#include "header.h"

static void serverListenerTask(mint taskId, void* vtarg)
{
    Server server = (Server)vtarg;
    
    #ifdef _DEBUG
    printf("%s\n%s[serverListenerTask->CALL]%s\n\tlisten socket id = %I64d\n\ttask id = %I64d\n\n", 
        getCurrentTime(),
        BLUE, RESET, 
        (int64_t)server->listenSocket, (int64_t)taskId
    );
    #endif
    
    while (server->libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        serverSelect(server);
        serverCheck(server);
        serverAccept(server);
        serverRecv(server);
    }

    #ifdef _DEBUG
    printf("%s\n%s[serverListenerTask->END]%s\n\tlisten socket id = %I64d\n\ttask id = %I64d\n\n", 
        getCurrentTime(),
        YELLOW, RESET, 
        (int64_t)server->listenSocket, (int64_t)taskId
    );
    #endif
}

/*serverListen[serverPtr] -> taskId*/
DLLEXPORT int serverListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    Server server = (Server)MArgument_getInteger(Args[0]);
    mint taskId;

    #ifdef _DEBUG
    printf("%s\n%s[serverListen->CALL]%s\n\tlisten socket id = %I64d\n\n", 
        getCurrentTime(),
        BLUE, RESET, 
        server->listenSocket
    );
    #endif

    taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(serverListenerTask, server);
    server->taskId = taskId;

    #ifdef _DEBUG
    printf("%s\n%s[serverListen->SUCCESS]%s\n\tlisten task id = %I64d\n\n", 
        getCurrentTime(),
        GREEN, RESET, 
        taskId
    );
    #endif

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

/*
    SELECT FUNCTIONS
*/

/*socketsSelect[{sockets}, length, timeout] -> {readySockets}*/
DLLEXPORT int socketsSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    MTensor socketIdsList = MArgument_getMTensor(Args[0]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets
    int timeout = (int)MArgument_getInteger(Args[2]); // timeout in microseconds

    int err;
    SOCKET *socketIds = (SOCKET*)libData->MTensor_getIntegerData(socketIdsList);
    SOCKET socketId;
    SOCKET maxFd = 0;
    fd_set readfds;
    FD_ZERO(&readfds);

    #ifdef _DEBUG
    printf("%s\n%ssocketSelect[%s", getCurrentTime(), BLUE, RESET); 
    #endif

    for (size_t i = 0; i < length; i++) {
        socketId = socketIds[i];
        if (socketId > maxFd) maxFd = socketId;
        FD_SET(socketId, &readfds);

        #ifdef _DEBUG
        if (i == 0) printf("%I64d", socketId);
        else printf(", %I64d", socketId);
        #endif
    }

    #ifdef _DEBUG
    printf("%s]%s -> ", BLUE, RESET);
    #endif

    struct timeval tv;
    tv.tv_sec  = timeout / 1000000;
    tv.tv_usec = timeout % 1000000;

    int result = select((int)(maxFd + 1), &readfds, NULL, NULL, &tv);
    if (result >= 0) {
        mint len = (mint)result;
        MTensor readySocketsTensor;
        libData->MTensor_new(MType_Integer, 1, &len, &readySocketsTensor);
        SOCKET *readySockets = (SOCKET*)libData->MTensor_getIntegerData(readySocketsTensor);
        
        #ifdef _DEBUG
        printf("%s{", GREEN);
        #endif

        int j = 0;
        for (size_t i = 0; i < length; i++) {
            socketId = socketIds[i];
            if (FD_ISSET(socketId, &readfds)) { 
                readySockets[j] = socketId;
                j++;

                #ifdef _DEBUG
                if (j == 1) printf("%I64d", socketId);
                else printf(", %I64d ", socketId);
                #endif
            }
        }

        #ifdef _DEBUG
        printf("}%s\n\n", RESET);
        #endif

        MArgument_setMTensor(Res, readySocketsTensor);
        return LIBRARY_NO_ERROR;
    } else {
        err = GETSOCKETERRNO();
        #ifdef _DEBUG
        printf("%sERROR = %d%s", RED, err, RESET); 
        #endif

        selectErrorMessage(libData, err);
        return LIBRARY_FUNCTION_ERROR;
    }
}

static void taskSelect(mint taskId, void* vtarg)
{
    SocketList socketList = (SocketList)vtarg;
    WolframLibraryData libData = socketList->libData;
    SOCKET *sockets = socketList->sockets;

    size_t length;
    SOCKET interrupt;
    SOCKET maxFd;
    struct timeval timeout;
    SOCKET socketId;
    int result;
    struct fd_set readfds;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        length = (size_t)socketList->length;
        interrupt = socketList->interrupt;
        maxFd = interrupt;

        FD_ZERO(&readfds);
        FD_SET(interrupt, &readfds);

        size_t length = (size_t)socketList->length;
        for (size_t i = 0; i < length; i++) {
            socketId = socketList->sockets[i];
            FD_SET(socketId, &readfds);
            if (socketId > maxFd) maxFd = socketId;
        }

        timeout.tv_sec = socketList->timeout / 1000000; // convert microseconds to seconds
        timeout.tv_usec = socketList->timeout % 1000000; // get remaining microseconds

        result = select(maxFd + 1, &readfds, NULL, NULL, &timeout);
        if (result > 0) {
            if (FD_ISSET(interrupt, &readfds)) {
                recv(interrupt, NULL, 0, 0);
            } else {
                pushSelect(libData, taskId, sockets, length, &readfds);
            }
        }
    }
}

/*createTaskSelect[socketList]*/
DLLEXPORT int createTaskSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    void *socketListPtr = (void *)MArgument_getInteger(Args[0]);

    #ifdef _DEBUG
    printf("%s\n%screateTaskSelect[%s%p%s]%s -> ", getCurrentTime(), BLUE, RESET, socketListPtr, BLUE, RESET);
    #endif

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(taskSelect, socketListPtr);
    
    #ifdef _DEBUG
    printf("%s%I64d%s\n\n", GREEN, taskId, RESET);
    #endif

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

static int socketListSelect(SocketList socketList, struct fd_set *readfds)
{
    size_t length;
    SOCKET interrupt;
    SOCKET maxFd;
    struct timeval timeout;
    SOCKET socketId;
    int result;

    length = (size_t)socketList->length;
    interrupt = socketList->interrupt;
    maxFd = interrupt;

    FD_ZERO(readfds);
    FD_SET(interrupt, readfds);

    for (size_t i = 0; i < length; i++) {
        socketId = socketList->sockets[i];
        FD_SET(socketId, readfds);
        if (socketId > maxFd) maxFd = socketId;
    }

    timeout.tv_sec = socketList->timeout / 1000000; // convert microseconds to seconds
    timeout.tv_usec = socketList->timeout % 1000000; // get remaining microseconds

    result = select(maxFd + 1, readfds, NULL, NULL, &timeout);
    return result;
}

static int serverSelectReady(Server server, struct fd_set *readfds)
{
    struct timeval timeout;
    SOCKET socketId;
    int result;

    size_t length = (size_t)server->clientsLength;
    SOCKET interrupt = server->interrupt;
    SOCKET maxFd = interrupt;

    FD_ZERO(readfds);
    FD_SET(interrupt, readfds);
    FD_SET(server->listenSocket, readfds);

    maxFd = max(interrupt, server->listenSocket);

    for (size_t i = 0; i < length; i++) {
        socketId = server->clients[i];
        FD_SET(socketId, readfds);
        if (socketId > maxFd) maxFd = socketId;
    }

    timeout.tv_sec = server->timeout / 1000000; // convert microseconds to seconds
    timeout.tv_usec = server->timeout % 1000000; // get remaining microseconds

    result = select(maxFd + 1, readfds, NULL, NULL, &timeout);
    return result;
}

static void taskSelectAcceptRecv(mint taskId, void* vtarg)
{
    Server server = (Server)vtarg;
    WolframLibraryData libData = server->libData;
    SOCKET *clients = server->clients;

    size_t length;
    SOCKET maxFd;
    struct timeval timeout;
    SOCKET socketId;
    int result;
    struct fd_set readfds;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        timeout.tv_sec = server->timeout / 1000000; // convert microseconds to seconds
        timeout.tv_usec = server->timeout % 1000000; // get remaining microseconds

        FD_ZERO(&readfds);
        FD_SET(server->interrupt, &readfds);
        FD_SET(server->listenSocket, &readfds);

        maxFd = max(server->interrupt, server->listenSocket);

        size_t length = (size_t)server->clientsLength;
        for (size_t i = 0; i < length; i++) {
            socketId = clients[i];
            FD_SET(socketId, &readfds);
            if (socketId > maxFd) maxFd = socketId;
        }
    }
    
}

/*createTaskSelectAcceptRecv[server]*/
DLLEXPORT int createTaskSelectAcceptRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    void *serverPtr = (void *)MArgument_getInteger(Args[0]);

    #ifdef _DEBUG
    printf("%s\n%screateTaskSelectAcceptRecv[%s%p%s]%s -> ", getCurrentTime(), BLUE, RESET, serverPtr, BLUE, RESET);
    #endif

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(taskSelectAcceptRecv, serverPtr);
    
    #ifdef _DEBUG
    printf("%s%I64d%s\n\n", GREEN, taskId, RESET);
    #endif

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

static void taskSelectRecvFrom(mint taskId, void *vtarg)
{
    SocketList socketList = (SocketList)vtarg;
    WolframLibraryData libData = socketList->libData;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        
    }
    
}

/*createTaskSelectAcceptRecv[{udpSockets}] -> taskId*/
DLLEXPORT int createTaskSelectRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    void *socketListPtr = (void *)MArgument_getInteger(Args[0]);

    #ifdef _DEBUG
    printf("%s\n%screateTaskSelectRecvFrom[%s%p%s]%s -> ", getCurrentTime(), BLUE, RESET, socketListPtr, BLUE, RESET);
    #endif

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(taskSelectRecvFrom, socketListPtr);
    
    #ifdef _DEBUG
    printf("%s%I64d%s\n\n", GREEN, taskId, RESET);
    #endif

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}