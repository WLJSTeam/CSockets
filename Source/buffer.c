#include "buffer.h"


DLLEXPORT int socketBufferCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    mint bufferSize = (mint)MArgument_getInteger(Args[0]);

    if (bufferSize <= 0) {
        return LIBRARY_FUNCTION_ERROR;
    }

    BYTE *buffer = malloc(bufferSize * sizeof(BYTE));
    if (!buffer) {
        return LIBRARY_FUNCTION_ERROR;
    }
    uintptr_t bufferPtr = (uintptr_t)buffer;
    MArgument_setInteger(Res, bufferPtr);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketBufferRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    BYTE *buffer = (BYTE *)MArgument_getInteger(Args[0]);
    free(buffer);
    return LIBRARY_NO_ERROR;
}