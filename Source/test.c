#include "test.h"


DLLEXPORT int test(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 0) return LIBRARY_FUNCTION_ERROR;
    DataStore result;
    result = libData->ioLibraryFunctions->createDataStore();
    if (!result) return LIBRARY_MEMORY_ERROR;
    libData->ioLibraryFunctions->DataStore_addInteger(result, 123);
    libData->ioLibraryFunctions->DataStore_addString(result, "test");
    MArgument_setDataStore(Res, result);
    return LIBRARY_NO_ERROR;
}
