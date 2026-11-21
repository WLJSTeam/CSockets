#include "WolframLibrary.h"
#include "WolframNumericArrayLibrary.h"

DLLEXPORT mint WolframLibrary_getVersion(void) { return WolframLibraryVersion; }
DLLEXPORT int WolframLibrary_initialize(WolframLibraryData data) { return LIBRARY_NO_ERROR; }

DLLEXPORT int tensorShares(WolframLibraryData data, mint argc, MArgument *args, MArgument result)
{
    MTensor tensor = MArgument_getMTensor(args[0]);
    mint count = data->MTensor_shareCount(tensor);
    data->MTensor_disown(tensor);
    MArgument_setInteger(result, count);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int arrayShares(WolframLibraryData data, mint argc, MArgument *args, MArgument result)
{
    MNumericArray array = MArgument_getMNumericArray(args[0]);
    mint count = data->numericarrayLibraryFunctions->MNumericArray_shareCount(array);
    data->numericarrayLibraryFunctions->MNumericArray_disown(array);
    MArgument_setInteger(result, count);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int retainTensor(WolframLibraryData data, mint argc, MArgument *args, MArgument result)
{
    /* Intentionally retain a reference to verify that Close releases all shares. */
    return LIBRARY_NO_ERROR;
}
