import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// True when [error] means "couldn't reach the server" (offline, timeout),
/// as opposed to the server answering with a rejection. Only the former is
/// worth queueing and retrying.
bool isConnectivityError(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is http.ClientException ||
    error is HandshakeException;
