#ifndef ADDRESS_H
#define ADDRESS_H

#include "common.h"

DLLEXPORT int socketAddressInfoCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketAddressInfoRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketAddressGet(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

#endif