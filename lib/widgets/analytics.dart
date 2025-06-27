import 'package:fl_chart/fl_chart.dart';
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
  String selectedGraphMetric = 'temperature';
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
          .orderBy('timestamp', descending: false)
          .limit(500)
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
            return aTime.compareTo(bTime);
          }
          
          if (aTime is String && bTime is String) {
            try {
              final aDate = DateTime.parse(aTime);
              final bDate = DateTime.parse(bTime);
              return aDate.compareTo(bDate);
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

  List<Map<String, dynamic>> _getReadingsForTimeRange(String timeRange) {
    DateTime cutoffTime;
    switch (timeRange) {
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
        return readings;
    }

    return readings.where((reading) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Analytics Dashboard'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
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
                ? Center(child: CircularProgressIndicator(color: Colors.green[700]))
                : readings.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryStats(),
                            SizedBox(height: 24),
                            _buildCurrentTrendSection(),
                            SizedBox(height: 24),
                            _buildTimeBasedGraphsSection(),
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

  Widget _buildCurrentTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Trend Analysis',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        SizedBox(height: 12),
        _buildGraphMetricSelector(),
        SizedBox(height: 16),
        Container(
          height: 300,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: readings.isEmpty ? 
            Center(child: Text('No data available', style: TextStyle(color: Colors.grey[600]))) : 
            _buildLineChart(readings),
        ),
      ],
    );
  }

  Widget _buildTimeBasedGraphsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historical Trends',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        SizedBox(height: 16),
        _buildTimeBasedGraphs(),
      ],
    );
  }

  Widget _buildTimeBasedGraphs() {
    return Column(
      children: [
        _buildTimeRangeGraph('Last 24 Hours', 'day'),
        SizedBox(height: 16),
        _buildTimeRangeGraph('Last 7 Days', 'week'),
        SizedBox(height: 16),
        _buildTimeRangeGraph('Last 30 Days', 'month'),
      ],
    );
  }

  Widget _buildTimeRangeGraph(String title, String timeRange) {
    List<Map<String, dynamic>> timeRangeReadings = _getReadingsForTimeRange(timeRange);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getTimeRangeIcon(timeRange),
                color: Colors.green[700],
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800],
                ),
              ),
              Spacer(),
              Text(
                '${timeRangeReadings.length} readings',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 200,
            child: timeRangeReadings.isEmpty
                ? Center(
                    child: Text(
                      'No data available for this period',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : _buildLineChart(timeRangeReadings, isCompact: true, timeRange: timeRange),
          ),
        ],
      ),
    );
  }

  IconData _getTimeRangeIcon(String timeRange) {
    switch (timeRange) {
      case 'day':
        return Icons.today;
      case 'week':
        return Icons.date_range;
      case 'month':
        return Icons.calendar_month;
      default:
        return Icons.timeline;
    }
  }

Widget _buildLineChart(List<Map<String, dynamic>> chartReadings, {bool isCompact = false, String? timeRange}) {
  List<FlSpot> spots = [];
  
  for (int i = 0; i < chartReadings.length; i++) {
    final reading = chartReadings[i];
    final value = reading[selectedGraphMetric]?.toDouble() ?? 0.0;
    spots.add(FlSpot(i.toDouble(), value));
  }

  if (spots.isEmpty) {
    return Center(child: Text('No data points available'));
  }

  // Calculate min and max values for better scaling
  double minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
  double maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
  
  // Handle case where all values are the same (avoid zero interval)
  if (minY == maxY) {
    // If all values are the same, create a small range around the value
    if (minY == 0) {
      minY = -1;
      maxY = 1;
    } else {
      double padding = minY.abs() * 0.1;
      minY = minY - padding;
      maxY = maxY + padding;
    }
  } else {
    // Normal case: add padding
    double padding = (maxY - minY) * 0.1;
    minY = (minY - padding).clamp(0, double.infinity);
    maxY = maxY + padding;
  }

  // Ensure the interval is never zero
  double range = maxY - minY;
  double horizontalInterval = range / 4;
  
  // Safety check: if interval is still too small, set a minimum
  if (horizontalInterval < 0.1) {
    horizontalInterval = 0.1;
  }

  return LineChart(
    LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: false,
        horizontalInterval: horizontalInterval, // Use the safe interval
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            interval: horizontalInterval, // Use the same safe interval
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  value.toStringAsFixed(1), // Show decimal for better precision
                  style: TextStyle(
                    fontSize: isCompact ? 9 : 10,
                    color: Colors.grey[600],
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: chartReadings.length > 10 ? (chartReadings.length / 5).ceilToDouble() : 1,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              if (index >= 0 && index < chartReadings.length) {
                return Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    _formatChartTime(chartReadings[index]['timestamp'], timeRange ?? selectedTimeRange),
                    style: TextStyle(
                      fontSize: isCompact ? 8 : 9,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              }
              return Text('');
            },
          ),
        ),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: _getMetricColor(selectedGraphMetric),
          barWidth: isCompact ? 2 : 3,
          belowBarData: BarAreaData(
            show: true,
            color: _getMetricColor(selectedGraphMetric).withOpacity(0.1),
          ),
          dotData: FlDotData(
            show: spots.length <= 20,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: _getMetricColor(selectedGraphMetric),
                strokeWidth: 1,
                strokeColor: Colors.white,
              );
            },
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBorder: BorderSide.none,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              int index = touchedSpot.x.toInt();
              if (index >= 0 && index < chartReadings.length) {
                String time = _formatTooltipTime(chartReadings[index]['timestamp']);
                String value = '${touchedSpot.y.toStringAsFixed(1)}${_getMetricUnit(selectedGraphMetric)}';
                return LineTooltipItem(
                  '$time\n$value',
                  TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                );
              }
              return null;
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
      ),
    ),
  );
}

  Color _getMetricColor(String metric) {
    switch (metric) {
      case 'temperature':
        return Colors.deepOrange;
      case 'humidity':
        return Colors.blue;
      case 'soilMoisture':
        return Colors.green[700]!;
      default:
        return Colors.green[700]!;
    }
  }

  String _getMetricUnit(String metric) {
    switch (metric) {
      case 'temperature':
        return '°C';
      case 'humidity':
      case 'soilMoisture':
        return '%';
      default:
        return '';
    }
  }

  String _formatChartTime(dynamic timestamp, String timeRange) {
    DateTime dateTime = _parseTimestamp(timestamp);
    
    switch (timeRange) {
      case 'hour':
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      case 'day':
        return '${dateTime.hour.toString().padLeft(2, '0')}h';
      case 'week':
        return '${dateTime.day}/${dateTime.month}';
      case 'month':
        return '${dateTime.day}/${dateTime.month}';
      default:
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatTooltipTime(dynamic timestamp) {
    DateTime dateTime = _parseTimestamp(timestamp);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildGraphMetricSelector() {
    return Container(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildGraphMetricChip('Temperature', 'temperature', Icons.thermostat),
            SizedBox(width: 8),
            _buildGraphMetricChip('Humidity', 'humidity', Icons.water_drop),
            SizedBox(width: 8),
            _buildGraphMetricChip('Soil Moisture', 'soilMoisture', Icons.grass),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphMetricChip(String label, String value, IconData icon) {
    bool isSelected = selectedGraphMetric == value;
    return Container(
      height: 40,
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              selectedGraphMetric = value;
            });
          }
        },
        selectedColor: _getMetricColor(value),
        backgroundColor: Colors.grey[100],
        elevation: isSelected ? 2 : 0,
        pressElevation: 4,
      ),
    );
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else if (timestamp is DateTime) {
      return timestamp;
    }
    return DateTime.now();
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Time Range: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.green[800],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['hour', 'day', 'week', 'month'].map((range) {
                  bool isSelected = selectedTimeRange == range;
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        _getTimeRangeLabel(range),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedTimeRange = range;
                          });
                          _loadAnalyticsData();
                        }
                      },
                      selectedColor: Colors.green[600],
                      backgroundColor: Colors.grey[100],
                      elevation: isSelected ? 2 : 0,
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
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 24),
          Text(
            'No sensor data available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Data will appear here once sensors start reporting',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAnalyticsData,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (readings.isEmpty) return SizedBox.shrink();

    double avgTemp = readings.map((r) => (r['temperature'] ?? 0.0) as double).reduce((a, b) => a + b) / readings.length;
    double avgHumidity = readings.map((r) => (r['humidity'] ?? 0.0) as double).reduce((a, b) => a + b) / readings.length;
    double avgSoilMoisture = readings.map((r) => (r['soilMoisture'] ?? 0.0) as double).reduce((a, b) => a + b) / readings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary Statistics',
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
                Colors.deepOrange,
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
          Colors.green[700]!,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Readings (${readings.length} total)',
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
          columns: [
            DataColumn(
              label: Text(
                'Time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                'Temp (°C)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                'Humidity (%)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DataColumn(
              label: Text(
                'Soil Moisture (%)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          rows: readings.take(20).map((reading) {
            return DataRow(
              cells: [
                DataCell(Text(_formatDataTableTime(reading['timestamp']))),
                DataCell(Text((reading['temperature'] ?? 0.0).toStringAsFixed(1))),
                DataCell(Text((reading['humidity'] ?? 0.0).toStringAsFixed(1))),
                DataCell(Text((reading['soilMoisture'] ?? 0.0).toStringAsFixed(1))),
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