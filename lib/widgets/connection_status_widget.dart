import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/connection_status.dart' as cs;

class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final status = provider.connectionStatus;
        final hasErrors = status.hasAnyError;

        if (!hasErrors &&
            status.entsoeStatus != cs.ConnectionState.connecting &&
            status.tcpStatus != cs.ConnectionState.connecting) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: hasErrors
              ? (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade50)
              : (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50),
          child: Row(
            children: [
              // ENTSO-E Status
              _buildStatusIcon(status.entsoeStatus),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ENTSO-E: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _getStatusColor(status.entsoeStatus),
                          ),
                        ),
                        Text(
                          _getStatusText(status.entsoeStatus),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(status.entsoeStatus),
                          ),
                        ),
                        if (status.lastEntsoeSync != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(${_formatTime(status.lastEntsoeSync!)})',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (status.hasEntsoeError)
                      Text(
                        status.entsoeError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // TCP Status
              _buildStatusIcon(status.tcpStatus),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'TCP/IP: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _getStatusColor(status.tcpStatus),
                          ),
                        ),
                        Text(
                          _getStatusText(status.tcpStatus),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(status.tcpStatus),
                          ),
                        ),
                        if (status.lastTcpSend != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(${_formatTime(status.lastTcpSend!)})',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (status.hasTcpError)
                      Text(
                        status.tcpError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(cs.ConnectionState state) {
    switch (state) {
      case cs.ConnectionState.connected:
        return const Icon(Icons.check_circle, color: Colors.green, size: 16);
      case cs.ConnectionState.connecting:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case cs.ConnectionState.error:
        return const Icon(Icons.error, color: Colors.red, size: 16);
      case cs.ConnectionState.disconnected:
        return Icon(Icons.circle_outlined, color: Colors.grey[400], size: 16);
    }
  }

  String _getStatusText(cs.ConnectionState state) {
    switch (state) {
      case cs.ConnectionState.connected:
        return 'Connected';
      case cs.ConnectionState.connecting:
        return 'Connecting...';
      case cs.ConnectionState.error:
        return 'Error';
      case cs.ConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  Color _getStatusColor(cs.ConnectionState state) {
    switch (state) {
      case cs.ConnectionState.connected:
        return Colors.green;
      case cs.ConnectionState.connecting:
        return Colors.blue;
      case cs.ConnectionState.error:
        return Colors.red;
      case cs.ConnectionState.disconnected:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }
}
