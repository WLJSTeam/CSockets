#include "common.h"

typedef struct SocketSelectArgs_st
{
    WolframLibraryData libData; 
    SOCKET *sockets;
    size_t length;
    mint timeout;
} *SocketSelectArgs;


void socketsSelectTask(mint taskId, void *taskArgs);

int socketsSelectAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

typedef struct SocketSelectLoopArgs_st {
    WolframLibraryData libData;
    SocketList socketList;
    mint timeout;
} *SocketSelectLoopArgs;

void socketsSelectLoopTask(mint taskId, void *taskArgs);

int socketsSelectLoopAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);