#include "sync.h"

DLLEXPORT int createEvent(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    FastEvent* event = create_event();
    MArgument_setInteger(Res, (mint)(intptr_t)event);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int destroyEvent(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    FastEvent* event = (FastEvent*)MArgument_getInteger(Args[0]);
    destroy_event(event);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int signalEvent(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    FastEvent* event = (FastEvent*)MArgument_getInteger(Args[0]);
    signal_event(event);
    return LIBRARY_NO_ERROR;
}
