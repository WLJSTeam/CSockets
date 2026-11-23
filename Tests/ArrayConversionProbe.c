#include "common.h"


DLLEXPORT int copyBytes(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("copyBytes: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MNumericArray input = MArgument_getMNumericArray(Args[0]);

    size_t length = 0;
    BYTE *bytes = ByteFromMNumericArray(libData, input, &length);
    MNumericArray result = MNumericArrayFromByte(libData, bytes, length);

    if (!result) {
        libData->Message("copyBytes: conversion failed");
        return LIBRARY_MEMORY_ERROR;
    }

    if (length > 0) {
        bytes[0] ^= 255;
    }

    MArgument_setMNumericArray(Res, result);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int copySockets(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("copySockets: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor input = MArgument_getMTensor(Args[0]);

    size_t length = 0;
    SOCKET *sockets = SocketFromMTensor(libData, input, &length);

    if (!sockets) {
        libData->Message("copySockets: conversion failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor result = MTensorFromSocket(libData, sockets, length);
    free(sockets);

    if (!result) {
        libData->Message("copySockets: allocation failed");
        return LIBRARY_MEMORY_ERROR;
    }

    MArgument_setMTensor(Res, result);
    return LIBRARY_NO_ERROR;
}
