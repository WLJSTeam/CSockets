#ifndef BUFFER_H
#define BUFFER_H


#include "common.h"


DLLEXPORT int socketBufferCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


DLLEXPORT int socketBufferRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


#endif