import 'package:agriaid/widgets/analytics.dart';
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
      final snapshot = await _firestore
          .collection('sensor_readings')
          .where('userId', isEqualTo: _authService.currentUser!.uid)
          .limit(50)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final sortedDocs = snapshot.docs.toList();
        sortedDocs.sort((a, b) {
          final aTime = a.data()['timestamp'];
          final bTime = b.data()['timestamp'];
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final double temperature = double.parse(_temperatureController.text);
      final double humidity = double.parse(_humidityController.text);
      final double soilMoisture = double.parse(_soilMoistureController.text);

      if (humidity < 0 || humidity > 100) {
        throw Exception('Humidity must be between 0-100%');
      }
      if (soilMoisture < 0 || soilMoisture > 100) {
        throw Exception('Soil moisture must be between 0-100%');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.green[700]),
                  SizedBox(height: 16),
                  Text('Recording data...'),
                ],
              ),
            ),
          ),
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

      _temperatureController.clear();
      _humidityController.clear();
      _soilMoistureController.clear();

      Navigator.of(context).pop();
      Navigator.of(context).pop();

      await _loadLatestReadings();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Sensor reading recorded successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

void _showRecordDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sensors,
                      color: Colors.green[700],
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Record Sensor Data',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 24),
                  _buildInputField(
                    controller: _temperatureController,
                    label: 'Temperature',
                    unit: '°C',
                    icon: Icons.thermostat,
                    iconColor: Colors.orange,
                    hint: 'e.g., 25.5',
                  ),
                  SizedBox(height: 16),
                  _buildInputField(
                    controller: _humidityController,
                    label: 'Humidity',
                    unit: '%',
                    icon: Icons.water_drop,
                    iconColor: Colors.blue,
                    hint: 'e.g., 65.0',
                  ),
                  SizedBox(height: 16),
                  _buildInputField(
                    controller: _soilMoistureController,
                    label: 'Soil Moisture',
                    unit: '%',
                    icon: Icons.grass,
                    iconColor: Colors.brown,
                    hint: 'e.g., 45.0',
                  ),
                  SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _recordReading,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'Record',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
        ),
      );
    },
  );
}


  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '$label ($unit)',
          hintText: hint,
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Sign Out'),
            ],
          ),
          content: Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _authService.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Sign Out'),
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
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green[700]),
                  SizedBox(height: 16),
                  Text(
                    'Loading your farm data...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadLatestReadings();
              },
              color: Colors.green[700],
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverPadding(
                    padding: EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildQuickActionsSection(),
                        SizedBox(height: 32),
                        _buildLatestReadingsSection(),
                        SizedBox(height: 32),
                        _buildStatusOverview(),
                        SizedBox(height: 100), // Extra padding at bottom
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

 Widget _buildSliverAppBar() {
  return SliverAppBar(
    expandedHeight: 100, // keep as requested
    floating: false,
    pinned: true,
    backgroundColor: Colors.green[700],
    foregroundColor: Colors.white,
    elevation: 0,
    actions: [
      IconButton(
        icon: Icon(Icons.analytics_outlined),
        onPressed: _navigateToAnalytics,
        tooltip: 'View Analytics',
      ),
      PopupMenuButton(
        icon: Icon(Icons.more_vert),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                SizedBox(width: 12),
                Text('Sign Out'),
              ],
            ),
          ),
        ],
      ),
    ],
    flexibleSpace: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // When collapsed, the top padding will shrink, so we can toggle visibility
        final bool isCollapsed = constraints.maxHeight <= kToolbarHeight + 20;

        return FlexibleSpaceBar(
          centerTitle: true,
          titlePadding: isCollapsed
              ? EdgeInsets.only(bottom: 12)
              : EdgeInsets.zero, // hide title when expanded
          title: isCollapsed
              ? Text(
                  'AgriAid',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.green[600]!, Colors.green[800]!],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.eco,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${userData?['fullName']?.split(' ')[0] ?? 'Farmer'}!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Monitor your farm conditions',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Record Data',
                subtitle: 'Add new readings',
                icon: Icons.add_circle_outline,
                color: Colors.green,
                onTap: _showRecordDialog,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                title: 'Analytics',
                subtitle: 'View trends',
                icon: Icons.bar_chart,
                color: Colors.blue,
                onTap: _navigateToAnalytics,
              ),
            ),
          ],
        ),
      ],
    );
  }

 Widget _buildActionCard({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 22,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget _buildLatestReadingsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Current Conditions',
            style: TextStyle(
              fontSize: 20, // reduced from 22
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          if (latestReadings != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), // reduced padding
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16), // reduced radius
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, // reduced from 8
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4), // reduced from 6
                  Text(
                    'Live',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 11, // reduced from 12
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      SizedBox(height: 10), // reduced from 16
      if (latestReadings == null)
        _buildNoDataCard()
      else
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSensorCard(
                    title: 'Temperature',
                    value: latestReadings!['temperature']?.toStringAsFixed(1) ?? '--',
                    unit: '°C',
                    icon: Icons.thermostat,
                    color: Colors.orange,
                    trend: _getTrend('temperature'),
                    // The card itself will be smaller by modifying _buildSensorCard
                  ),
                ),
                SizedBox(width: 10), // reduced from 16
                Expanded(
                  child: _buildSensorCard(
                    title: 'Humidity',
                    value: latestReadings!['humidity']?.toStringAsFixed(1) ?? '--',
                    unit: '%',
                    icon: Icons.water_drop,
                    color: Colors.blue,
                    trend: _getTrend('humidity'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10), // reduced from 16
            _buildSensorCard(
              title: 'Soil Moisture',
              value: latestReadings!['soilMoisture']?.toStringAsFixed(1) ?? '--',
              unit: '%',
              icon: Icons.grass,
              color: Colors.brown,
              isFullWidth: true,
              trend: _getTrend('soilMoisture'),
            ),
            SizedBox(height: 8), // reduced from 12
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), // reduced padding
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16), // reduced radius
              ),
              child: Text(
                'Last updated: ${_formatTimestamp(latestReadings!['timestamp'])}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11, // reduced from 12
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

  Widget _buildNoDataCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sensors_off,
              size: 32,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No sensor data available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Record your first sensor reading to start monitoring',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

 Widget _buildStatusOverview() {
  if (latestReadings == null) return SizedBox.shrink();

  final temp = latestReadings!['temperature'] ?? 0;
  final humidity = latestReadings!['humidity'] ?? 0;
  final soilMoisture = latestReadings!['soilMoisture'] ?? 0;

  String status = 'Optimal';
  Color statusColor = Colors.green;
  IconData statusIcon = Icons.check_circle;

  if (temp < 15 || temp > 35 || humidity < 40 || humidity > 80 || soilMoisture < 30) {
    status = 'Needs Attention';
    statusColor = Colors.orange;
    statusIcon = Icons.warning;
  }

  if (temp < 10 || temp > 40 || humidity < 20 || humidity > 90 || soilMoisture < 20) {
    status = 'Critical';
    statusColor = Colors.red;
    statusIcon = Icons.error;
  }

  return Transform.translate(
    offset: Offset(0, -30), // move up by 30 logical pixels (≈ 30%)
    child: Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 18,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  String? trend,
  bool isFullWidth = false,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14), // match action card padding
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    width: isFullWidth ? double.infinity : null,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 22, // smaller icon
            color: color,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '$value $unit',
          style: TextStyle(
            fontSize: 14, // reduced
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 11, // reduced
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        if (trend != null) ...[
          SizedBox(height: 4),
          Text(
            'Trend: $trend',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ]
      ],
    ),
  );
}

  String? _getTrend(String sensorType) {
    // This is a placeholder for trend calculation
    // You would implement actual trend calculation based on historical data
    return null; // Return something like '+2.1°' or 'stable' based on your logic
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