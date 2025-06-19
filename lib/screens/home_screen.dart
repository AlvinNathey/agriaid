import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? userData;
  bool isLoading = true;
  Map<String, dynamic>? latestReadings;
  String selectedTimeRange = 'hour';

  // Controllers for data input
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _soilMoistureController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLatestReadings();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _soilMoistureController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _authService.getUserData(_authService.currentUser!.uid);
      if (doc.exists) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadLatestReadings() async {
    try {
      // First try to get readings without ordering to avoid index issues
      final snapshot = await _firestore
          .collection('sensor_readings')
          .where('userId', isEqualTo: _authService.currentUser!.uid)
          .limit(50) // Get more documents to find the latest
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Sort the documents by timestamp in memory to find the latest
        final sortedDocs = snapshot.docs.toList();
        sortedDocs.sort((a, b) {
          final aTime = a.data()['timestamp'];
          final bTime = b.data()['timestamp'];
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime); // Descending order
          }
          
          // Handle string timestamps if they exist
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
          latestReadings = sortedDocs.first.data();
        });
      } else {
        setState(() {
          latestReadings = null;
        });
      }
    } catch (e) {
      print('Error loading latest readings: $e');
      setState(() {
        latestReadings = null;
      });
    }
  }

  Future<void> _recordReading() async {
    if (_temperatureController.text.isEmpty ||
        _humidityController.text.isEmpty ||
        _soilMoistureController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all sensor readings'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final double temperature = double.parse(_temperatureController.text);
      final double humidity = double.parse(_humidityController.text);
      final double soilMoisture = double.parse(_soilMoistureController.text);

      // Validate ranges
      if (humidity < 0 || humidity > 100) {
        throw Exception('Humidity must be between 0-100%');
      }
      if (soilMoisture < 0 || soilMoisture > 100) {
        throw Exception('Soil moisture must be between 0-100%');
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      await _firestore.collection('sensor_readings').add({
        'userId': _authService.currentUser!.uid,
        'temperature': temperature,
        'humidity': humidity,
        'soilMoisture': soilMoisture,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Clear controllers
      _temperatureController.clear();
      _humidityController.clear();
      _soilMoistureController.clear();

      // Close loading dialog
      Navigator.of(context).pop();

      // Close record dialog
      Navigator.of(context).pop();

      // Reload latest readings to refresh the display
      await _loadLatestReadings();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sensor reading recorded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRecordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.sensors, color: Colors.green[700]),
              SizedBox(width: 8),
              Text('Record Sensor Data'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _temperatureController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Temperature (°C)',
                    prefixIcon: Icon(Icons.thermostat),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 25.5',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _humidityController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Humidity (%)',
                    prefixIcon: Icon(Icons.water_drop),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 65.0',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _soilMoistureController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Soil Moisture (%)',
                    prefixIcon: Icon(Icons.grass),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 45.0',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _recordReading,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              child: Text('Record'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sign Out'),
          content: Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _authService.signOut();
              },
              child: Text('Sign Out'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyticsScreen(userId: _authService.currentUser!.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: Text(
          'AgriAid Monitor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: _navigateToAnalytics,
            tooltip: 'View Analytics',
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadLatestReadings();
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Colors.green[400]!, Colors.green[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  child: Icon(
                                    Icons.agriculture,
                                    size: 35,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back!',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        userData?['fullName'] ?? 'Farmer',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Monitor your farm\'s environmental conditions',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Current Readings
                    Text(
                      'Latest Readings',
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
                          child: _buildSensorCard(
                            title: 'Temperature',
                            value: latestReadings?['temperature']?.toStringAsFixed(1) ?? '--',
                            unit: '°C',
                            icon: Icons.thermostat,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSensorCard(
                            title: 'Humidity',
                            value: latestReadings?['humidity']?.toStringAsFixed(1) ?? '--',
                            unit: '%',
                            icon: Icons.water_drop,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildSensorCard(
                      title: 'Soil Moisture',
                      value: latestReadings?['soilMoisture']?.toStringAsFixed(1) ?? '--',
                      unit: '%',
                      icon: Icons.grass,
                      color: Colors.brown,
                      isFullWidth: true,
                    ),
                    
                    if (latestReadings != null) 
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Last updated: ${_formatTimestamp(latestReadings!['timestamp'])}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    SizedBox(height: 24),

                    // Quick Actions
                    Text(
                      'Quick Actions',
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
                          child: ElevatedButton.icon(
                            onPressed: _showRecordDialog,
                            icon: Icon(Icons.add_circle_outline),
                            label: Text('Record Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _navigateToAnalytics,
                            icon: Icon(Icons.analytics),
                            label: Text('View Analytics'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: color,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Unknown';
      }
    } else {
      return 'Unknown';
    }
    
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Analytics Screen
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
      // Simplified query to avoid index issues
      final snapshot = await _firestore
          .collection('sensor_readings')
          .where('userId', isEqualTo: widget.userId)
          .limit(100) // Get recent readings
          .get();

      if (snapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> allReadings = snapshot.docs.map((doc) => doc.data()).toList();
        
        // Filter by time range in memory
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

        // Sort by timestamp (newest first)
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
          // Time Range Selector
          Container(
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
          ),
          
          // Analytics Content
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : readings.isEmpty
                    ? Center(
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
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary Stats
                            _buildSummaryStats(),
                            SizedBox(height: 24),
                            
                            // Data Table
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
                        ),
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
    // Handle Unix timestamp (milliseconds)
    dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
  } else {
    return 'Unknown Format';
  }

  final now = DateTime.now();
  final difference = now.difference(dateTime);

  // Return relative time for recent timestamps
  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    // Return formatted date for older timestamps
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

String _formatFullDateTime(dynamic timestamp) {
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

  return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

String _getTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 30) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  } else {
    final years = (difference.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  }
}

// Add the missing closing bracket for _AnalyticsScreenState
}