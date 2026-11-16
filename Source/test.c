#include "test.h"


DLLEXPORT int test(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    DataStore result;
    result = libData->ioLibraryFunctions->createDataStore();
    libData->ioLibraryFunctions->DataStore_addInteger(result, 123);
    libData->ioLibraryFunctions->DataStore_addString(result, "test");
    MArgument_setDataStore(Res, result);
    return LIBRARY_NO_ERROR;
}
