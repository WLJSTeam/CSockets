socketListCreate = LibraryFunctionLoad[$lib, "socketListCreate", {Integer, Integer}, Integer];


socketListSet = LibraryFunctionLoad[$lib, "socketListSet", {Integer, Integer}, Integer];


socketListRemove = LibraryFunctionLoad[$lib, "socketListRemove", {Integer}, Integer];


serverCreate = LibraryFunctionLoad[$lib, "serverCreate", {Integer, Integer, Integer, Integer, Integer}, Integer];


serverRemove = LibraryFunctionLoad[$lib, "serverRemove", {Integer}, Integer];


socketAddressInfoCreate = LibraryFunctionLoad[$lib, "socketAddressInfoCreate", {UTF8String}, Integer];


socketAddressInfoRemove = LibraryFunctionLoad[$lib, "socketAddressInfoRemove", {Integer}, Integer];


socketAddressCreate = LibraryFunctionLoad[$lib, "socketAddressCreate", {}, Integer];


socketAddressRemove = LibraryFunctionLoad[$lib, "socketAddressRemove", {Integer}, Integer];


socketBufferCreate = LibraryFunctionLoad[$lib, "socketBufferCreate", {Integer}, Integer];


socketBufferRemove = LibraryFunctionLoad[$lib, "socketBufferRemove", {Integer}, Integer];


socketCreate = LibraryFunctionLoad[$lib, "socketCreate", {Integer, Integer, Integer}, Integer];


socketClose = LibraryFunctionLoad[$lib, "socketClose", {}, Integer];


socketBind = LibraryFunctionLoad[$lib, "socketBind", {Integer, Integer}, Integer];


socketSetOpt = LibraryFunctionLoad[$lib, "socketSetOpt", {Integer, Integer, Integer, Integer}, Integer];


socketGetOpt = LibraryFunctionLoad[$lib, "socketGetOpt", {Integer, Integer, Integer}, Integer];


socketBlockingMode = LibraryFunctionLoad[$lib, "socketBlockingMode", {Integer, Integer}, Integer];


socketListen = LibraryFunctionLoad[$lib, "socketListen", {Integer, Integer}, Integer];


socketConnect = LibraryFunctionLoad[$lib, "socketConnect", {Integer, Integer, Integer}, Integer];


socketsCheck = LibraryFunctionLoad[$lib, "socketsCheck", {Integer}, MTensor];


socketAccept = LibraryFunctionLoad[$lib, "socketAccept", {Integer}, Integer];


socketRecv = LibraryFunctionLoad[$lib, "socketRecv", {Integer, Integer, Integer}, MNumericArray];


socketRecvFrom = LibraryFunctionLoad[$lib, "socketRecvFrom", {Integer, Integer, Integer, Integer}, MNumericArray];


socketSend = LibraryFunctionLoad[$lib, "socketSend", {MNumericArray}, Integer];


socketSendString = LibraryFunctionLoad[$lib, "socketSendString", {UTF8String}, Integer];


serverListen = LibraryFunctionLoad[$lib, "serverListen", {Integer}, Integer];


socketsSelect = LibraryFunctionLoad[$lib, "socketsSelect", {Integer, Integer}, MTensor];


createTaskSelect = LibraryFunctionLoad[$lib, "createTaskSelect", {Integer}, Integer];


createTaskSelectAcceptRecv = LibraryFunctionLoad[$lib, "createTaskSelectAcceptRecv", {Integer}, Integer];


createTaskSelectRecvFrom = LibraryFunctionLoad[$lib, "createTaskSelectRecvFrom", {Integer}, Integer];