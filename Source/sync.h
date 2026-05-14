#ifndef SYNC_H
#define SYNC_H


#include "common.h"


DLLEXPORT int getEventPtr(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


DLLEXPORT int destroyEvent(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


DLLEXPORT int signalEvent(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


#endif