enum ConnectionState {
  connected,
  disconnected,
  error,
  connecting,
}

class ConnectionStatus {
  final ConnectionState entsoeStatus;
  final ConnectionState tcpStatus;
  final String? entsoeError;
  final String? tcpError;
  final DateTime? lastEntsoeSync;
  final DateTime? lastTcpSend;
  final String? lastTcpResponse;

  ConnectionStatus({
    this.entsoeStatus = ConnectionState.disconnected,
    this.tcpStatus = ConnectionState.disconnected,
    this.entsoeError,
    this.tcpError,
    this.lastEntsoeSync,
    this.lastTcpSend,
    this.lastTcpResponse,
  });

  ConnectionStatus copyWith({
    ConnectionState? entsoeStatus,
    ConnectionState? tcpStatus,
    String? entsoeError,
    String? tcpError,
    DateTime? lastEntsoeSync,
    DateTime? lastTcpSend,
    String? lastTcpResponse,
  }) {
    return ConnectionStatus(
      entsoeStatus: entsoeStatus ?? this.entsoeStatus,
      tcpStatus: tcpStatus ?? this.tcpStatus,
      entsoeError: entsoeError ?? this.entsoeError,
      tcpError: tcpError ?? this.tcpError,
      lastEntsoeSync: lastEntsoeSync ?? this.lastEntsoeSync,
      lastTcpSend: lastTcpSend ?? this.lastTcpSend,
      lastTcpResponse: lastTcpResponse ?? this.lastTcpResponse,
    );
  }

  bool get hasEntsoeError =>
      entsoeStatus == ConnectionState.error && entsoeError != null;

  bool get hasTcpError =>
      tcpStatus == ConnectionState.error && tcpError != null;

  bool get hasAnyError => hasEntsoeError || hasTcpError;
}
