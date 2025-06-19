import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsScreen extends StatefulWidget {
  final String userId;

  const AnalyticsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String selectedTimeRange = 'hour';
  List<Map<String, dynamic>> readings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('sensor_readings')
          .where('userId', isEqualTo: widget.userId)
          .limit(100)
          .get();

      if (snapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> allReadings = snapshot.docs.map((doc) => doc.data()).toList();
        
        DateTime cutoffTime;
        switch (selectedTimeRange) {
          case 'hour':
            cutoffTime = DateTime.now().subtract(Duration(hours: 1));
            break;
          case 'day':
            cutoffTime = DateTime.now().subtract(Duration(days: 1));
            break;
          case 'week':
            cutoffTime = DateTime.now().subtract(Duration(days: 7));
            break;
          case 'month':
            cutoffTime = DateTime.now().subtract(Duration(days: 30));
            break;
          default:
            cutoffTime = DateTime.now().subtract(Duration(hours: 1));
        }

        List<Map<String, dynamic>> filteredReadings = allReadings.where((reading) {
          final timestamp = reading['timestamp'];
          if (timestamp is Timestamp) {
            return timestamp.toDate().isAfter(cutoffTime);
          } else if (timestamp is String) {
            try {
              final dateTime = DateTime.parse(timestamp);
              return dateTime.isAfter(cutoffTime);
            } catch (e) {
              return false;
            }
          }
          return false;
        }).toList();

        filteredReadings.sort((a, b) {
          final aTime = a['timestamp'];
          final bTime = b['timestamp'];
          
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          
          if (aTime is String && bTime is String) {
            try {
              final aDate = DateTime.parse(aTime);
              final bDate = DateTime.parse(bTime);
              return bDate.compareTo(aDate);
            } catch (e) {
              return 0;
            }
          }
          
          return 0;
        });

        setState(() {
          readings = filteredReadings;
          isLoading = false;
        });
      } else {
        setState(() {
          readings = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading analytics data: $e');
      setState(() {
        readings = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: Text('Analytics Dashboard'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTimeRangeSelector(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : readings.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryStats(),
                            SizedBox(height: 24),
                            _buildDataTableSection(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Time Range: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['hour', 'day', 'week', 'month'].map((range) {
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_getTimeRangeLabel(range)),
                      selected: selectedTimeRange == range,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedTimeRange = range;
                          });
                          _loadAnalyticsData();
                        }
                      },
                      selectedColor: Colors.green[200],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          Text(
            'for the selected time range',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (readings.isEmpty) return SizedBox.shrink();

    double avgTemp = readings.map((r) => r['temperature'] as double).reduce((a, b) => a + b) / readings.length;
    double avgHumidity = readings.map((r) => r['humidity'] as double).reduce((a, b) => a + b) / readings.length;
    double avgSoilMoisture = readings.map((r) => r['soilMoisture'] as double).reduce((a, b) => a + b) / readings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Average Values',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Avg Temperature',
                '${avgTemp.toStringAsFixed(1)}°C',
                Icons.thermostat,
                Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg Humidity',
                '${avgHumidity.toStringAsFixed(1)}%',
                Icons.water_drop,
                Colors.blue,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _buildStatCard(
          'Avg Soil Moisture',
          '${avgSoilMoisture.toStringAsFixed(1)}%',
          Icons.grass,
          Colors.brown,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    return Card(
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Readings (${readings.length} records)',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        SizedBox(height: 16),
        _buildDataTable(),
      ],
    );
  }

  Widget _buildDataTable() {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Temp (°C)')),
            DataColumn(label: Text('Humidity (%)')),
            DataColumn(label: Text('Soil Moisture (%)')),
          ],
          rows: readings.take(20).map((reading) {
            return DataRow(
              cells: [
                DataCell(Text(_formatDataTableTime(reading['timestamp']))),
                DataCell(Text(reading['temperature'].toStringAsFixed(1))),
                DataCell(Text(reading['humidity'].toStringAsFixed(1))),
                DataCell(Text(reading['soilMoisture'].toStringAsFixed(1))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getTimeRangeLabel(String range) {
    switch (range) {
      case 'hour':
        return 'Last Hour';
      case 'day':
        return 'Last Day';
      case 'week':
        return 'Last Week';
      case 'month':
        return 'Last Month';
      default:
        return range;
    }
  }

  String _formatDataTableTime(dynamic timestamp) {
    DateTime dateTime;

    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Invalid Date';
      }
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return 'Unknown Format';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}