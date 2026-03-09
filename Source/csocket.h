#include "common.h"

int socketCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketClose(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketSetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketGetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketSetBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketAccept(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketSend(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketSendString(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketsCheck(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int socketsSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);