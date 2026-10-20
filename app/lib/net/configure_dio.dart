export 'configure_dio_stub.dart'
    if (dart.library.io) 'configure_dio_io.dart'
    if (dart.library.js_interop) 'configure_dio_web.dart';
