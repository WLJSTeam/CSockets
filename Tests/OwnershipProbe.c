#include "WolframLibrary.h"
#include "WolframNumericArrayLibrary.h"


DLLEXPORT mint WolframLibrary_getVersion(void)
{
    return WolframLibraryVersion;
}


DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData)
{
    (void)libData;
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int tensorShares(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("tensorShares: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor tensor = MArgument_getMTensor(Args[0]);

    mint count = libData->MTensor_shareCount(tensor);
    libData->MTensor_disown(tensor);
    MArgument_setInteger(Res, count);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int arrayShares(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("arrayShares: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MNumericArray array = MArgument_getMNumericArray(Args[0]);

    mint count = libData->numericarrayLibraryFunctions->MNumericArray_shareCount(array);
    libData->numericarrayLibraryFunctions->MNumericArray_disown(array);
    MArgument_setInteger(Res, count);
    return LIBRARY_NO_ERROR;
}
