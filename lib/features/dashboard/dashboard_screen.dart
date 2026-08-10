import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import '../../core/widgets/loading_overlay.dart';
import '../../core/utils/pdf_helper.dart';
import '../../core/utils/uppercase_formatter.dart';
import 'dashboard_notifier.dart';
import 'dashboard_provider.dart';
import 'models/missing_certificate_model.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _vehicleDistChartKey = GlobalKey();
  final GlobalKey _revenueChartKey = GlobalKey();

  static const _districtHint = 'Select All District';
  static const _zoneHint = 'Select All Zone';
  static const _cameraHint = 'Select All Camera';
  static const _timeRangeHint = 'Select All Time Range';

  static const List<String> _timeRangeOptions = [
    'Select All Time Range',
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'Custom',
  ];

  String? _selectedDistrict = 'Select All District';
  String? _selectedZone = 'Select All Zone';
  String? _selectedCamera = 'Select All Camera';
  String? _selectedTimeRange = 'Today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTime _lastUpdatedTime = DateTime.now();
  bool _showOverviewFilters = false;
  String? _expandedComplianceCategory;







  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    
    // Auto Refresh every 20 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _refreshDashboardData();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshDashboardData() {
    if (!mounted) return;
    final state = ref.read(dashboardNotifierProvider);
    final cameraID = state.cameraLocationToId[_selectedCamera];
    final params = MissingCertificatesParams(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID,
      timeRange: _selectedTimeRange,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
    );
    ref.invalidate(missingCertificatesProvider(params));

    // Background fetch dashboard metrics (KPIs, offences, challans)
    ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID,
      timeRange: _selectedTimeRange,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
      isInitial: true,
    );
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0F5D55),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedTimeRange = 'Custom';
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    final state = ref.read(dashboardNotifierProvider);
    final cameraID = state.cameraLocationToId[_selectedCamera];
    ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID,
      timeRange: _selectedTimeRange,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
    );
  }



  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardNotifierProvider);
    final notifier = ref.watch(dashboardNotifierProvider.notifier);
    
    ref.listen<DashboardState>(dashboardNotifierProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (previous != next && !next.isLoading && next.error == null) {
        setState(() {
          _lastUpdatedTime = DateTime.now();
        });
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isMobile = !isDesktop;
    
    final summaryColumnCount = isDesktop ? 4 : 2;
    final donutColumnCount = isDesktop ? 6 : (screenWidth >= 750 ? 3 : 1);

    final cameraID = state.cameraLocationToId[_selectedCamera];
    final params = MissingCertificatesParams(
      district: _selectedDistrict,
      zone: _selectedZone,
      camera: cameraID,
      timeRange: _selectedTimeRange,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
    );

    ref.listen<AsyncValue<MissingCertificateModel>>(
      missingCertificatesProvider(params),
      (previous, next) {
        if (next is AsyncData && previous != next) {
          setState(() {
            _lastUpdatedTime = DateTime.now();
          });
        }
      },
    );

    final missingCertificatesAsync = ref.watch(missingCertificatesProvider(params));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),

      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: RefreshIndicator(
          onRefresh: () async {
            final camId = state.cameraLocationToId[_selectedCamera];
            final p = MissingCertificatesParams(
              district: _selectedDistrict,
              zone: _selectedZone,
              camera: camId,
              timeRange: _selectedTimeRange,
              customStartDate: _customStartDate,
              customEndDate: _customEndDate,
            );
            ref.invalidate(missingCertificatesProvider(p));
            await ref.read(missingCertificatesProvider(p).future);
            await notifier.fetchDashboard(
              district: _selectedDistrict,
              zone: _selectedZone,
              camera: camId,
              timeRange: _selectedTimeRange,
              customStartDate: _customStartDate,
              customEndDate: _customEndDate,
            );
            if (mounted) {
              setState(() {
                _lastUpdatedTime = DateTime.now();
              });
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            child: isMobile
                ? _buildMobileLayout(
                    context,
                    state,
                    notifier,
                    missingCertificatesAsync,
                    screenWidth,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Header Bar (Government of Telangana & Live Feed)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
                  child: LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isMobileHeader = headerConstraints.maxWidth < 750;
                      
                      final titleCol = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GOVERNMENT OF TELANGANA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Vehicle Identification & Enforcement Automation System',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F3260),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.verified,
                                color: Colors.teal.shade400,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      );

                      if (isMobileHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleCol,
                            const SizedBox(height: 12),
                            const _LiveFeedClock(),
                          ],
                        );
                      } else {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: titleCol),
                            const SizedBox(width: 16),
                            const _LiveFeedClock(),
                          ],
                        );
                      }
                    }
                  ),
                ),

                // Filter Bar (Transparent Container)
                Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 950;
                      
                      final districtDropdown = _buildDropdownField(
                        hint: _districtHint,
                        value: _selectedDistrict,
                        options: state.districts,
                        onChanged: (value) async {
                          setState(() {
                            _selectedDistrict = value;
                            _selectedZone = 'Select All Zone';
                            _selectedCamera = 'Select All Camera';
                          });
                          if (value != null && value != 'Select All District') {
                            final autoZone = await ref.read(dashboardNotifierProvider.notifier).fetchZonesForDistrict(value);
                            if (autoZone != null && mounted) {
                              setState(() => _selectedZone = autoZone);
                              ref.read(dashboardNotifierProvider.notifier).fetchCamerasForZone(autoZone);
                            }
                          } else {
                            ref.read(dashboardNotifierProvider.notifier).resetZones();
                          }
                          ref.read(dashboardNotifierProvider.notifier).resetCameras();
                        },
                        prefixIcon: Icons.location_on_outlined,
                      );

                      final zoneDropdown = _buildDropdownField(
                        hint: _zoneHint,
                        value: _selectedZone,
                        options: state.zones,
                        onChanged: (value) {
                          setState(() {
                            _selectedZone = value;
                            _selectedCamera = 'Select All Camera';
                          });
                          if (value != null && value != 'Select All Zone') {
                            ref.read(dashboardNotifierProvider.notifier).fetchCamerasForZone(value);
                          } else {
                            ref.read(dashboardNotifierProvider.notifier).resetCameras();
                          }
                        },
                        prefixIcon: Icons.location_city_outlined,
                      );

                      final cameraDropdown = _buildDropdownField(
                        hint: _cameraHint,
                        value: _selectedCamera,
                        options: state.cameras,
                        onChanged: (value) => setState(() => _selectedCamera = value),
                        prefixIcon: Icons.videocam_outlined,
                      );

                      // Time range: show date picker for 'Custom', else just set value
                      final timeRangeDropdown = _buildDropdownField(
                        hint: _timeRangeHint,
                        value: _selectedTimeRange,
                        options: _timeRangeOptions,
                        onChanged: (value) {
                          if (value == 'Custom') {
                            _pickCustomDateRange(context);
                          } else {
                            setState(() {
                              _selectedTimeRange = value;
                              _customStartDate = null;
                              _customEndDate = null;
                            });
                          }
                        },
                        prefixIcon: Icons.calendar_today_outlined,
                        suffix: _selectedTimeRange == 'Custom' && _customStartDate != null
                            ? Text(
                                '${_customStartDate!.day}/${_customStartDate!.month} – ${_customEndDate!.day}/${_customEndDate!.month}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF0F5D55)),
                              )
                            : null,
                      );

                      final submitButton = ElevatedButton(
                        onPressed: () {
                          final cameraID = state.cameraLocationToId[_selectedCamera];
                          notifier.fetchDashboard(
                            district: _selectedDistrict,
                            zone: _selectedZone,
                            camera: cameraID,
                            timeRange: _selectedTimeRange,
                            customStartDate: _customStartDate,
                            customEndDate: _customEndDate,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5D55),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Apply Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(child: districtDropdown),
                            const SizedBox(width: 12),
                            Expanded(child: zoneDropdown),
                            const SizedBox(width: 12),
                            Expanded(child: cameraDropdown),
                            const SizedBox(width: 12),
                            Expanded(child: timeRangeDropdown),
                            const SizedBox(width: 16),
                            submitButton,
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            districtDropdown,
                            const SizedBox(height: 8),
                            zoneDropdown,
                            const SizedBox(height: 8),
                            cameraDropdown,
                            const SizedBox(height: 8),
                            timeRangeDropdown,
                            const SizedBox(height: 12),
                            submitButton,
                          ],
                        );
                      }
                    },
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    20 + MediaQuery.of(context).padding.bottom + 96,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grid of 4 Key Metrics Cards
                      GridView.count(
                        crossAxisCount: summaryColumnCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: isMobile ? (screenWidth < 365 ? 1.35 : 1.5) : 2.8,
                        children: [
                           _buildKeyMetricCard(
                            context,
                            title: 'Total No.of Vehicles',
                            value: missingCertificatesAsync.maybeWhen(
                              data: (data) => NumberFormat.decimalPattern().format(data.vehicleCount),
                              orElse: () => '0',
                            ),
                            icon: Icons.directions_car,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3F42B9), Color(0xFF5B5EE6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'e-Challan',
                            value: state.eChallan,
                            icon: Icons.receipt_long,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B998), Color(0xFF059688)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              _showChallanDetailsModal(
                                context,
                                ref,
                                title: 'e-Challan',
                                challanTypes: const ["RAISE", "ECHALLAN", "E_CHALLAN"],
                              );
                            },
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'Manual Challan',
                            value: state.manualChallan,
                            icon: Icons.payments,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF455A64), Color(0xFF607D8B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              _showChallanDetailsModal(
                                context,
                                ref,
                                title: 'Manual Challan',
                                challanTypes: const ["COLLECT", "MANUAL"],
                              );
                            },
                          ),
                          _buildKeyMetricCard(
                            context,
                            title: 'Vehicles Seized',
                            value: state.seizedVehicles,
                            icon: Icons.block,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9E1B32), Color(0xFFC8102E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              _showChallanDetailsModal(
                                context,
                                ref,
                                title: 'Vehicles Seized',
                                challanTypes: const ["SEIZE", "SEIZED"],
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),



                      // Row/Grid of 6 Circular Charts (including Registration)
                      GridView.count(
                        crossAxisCount: donutColumnCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: isDesktop ? 0.65 : (screenWidth >= 768 ? 0.85 : 1.75),
                        children: _getSummaryMetrics(state.offenceData)
                            .map((metric) => _buildComplianceCard(metric))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      
                      // Bottom Section (Vehicle Distribution and Revenue Generated)
                      if (isMobile) ...[
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1.5,
                          shadowColor: Colors.black12,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Vehicle Distribution',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildChartMenu(context, 'Vehicle Distribution'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 300,
                                  child: missingCertificatesAsync.when(
                                    data: (data) {
                                      final chartData = [
                                        _ChartData('Fitness', data.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                                        _ChartData('Insurance', data.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                                        _ChartData('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                                        _ChartData('Permit', data.permitCertificateNotFound, const Color(0xFFD64D81)),
                                        _ChartData('Puc', data.pucCertificateNotFound, const Color(0xFF32353A)),
                                        _ChartData('Registration', data.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                                        _ChartData('All Clear', data.allClearNotFound, const Color(0xFF2FA85C)),
                                        _ChartData('Missing Data', data.weightCertificateNotFound, const Color(0xFFF5D671)),
                                      ];
                                      return SfCircularChart(
                                        legend: Legend(
                                          isVisible: true,
                                          overflowMode: LegendItemOverflowMode.wrap,
                                          position: LegendPosition.bottom,
                                          textStyle: const TextStyle(fontSize: 10),
                                        ),
                                        series: <DoughnutSeries<_ChartData, String>>[
                                          DoughnutSeries<_ChartData, String>(
                                            animationDuration: 0,
                                            dataSource: chartData,
                                            xValueMapper: (data, _) => data.label,
                                            yValueMapper: (data, _) => data.value,
                                            pointColorMapper: (data, _) => data.color,
                                            innerRadius: '60%',
                                            dataLabelSettings: const DataLabelSettings(
                                              isVisible: true,
                                              labelPosition: ChartDataLabelPosition.outside,
                                              textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                            dataLabelMapper: (data, _) => '${data.label}: ${data.value.toInt()}',
                                          ),
                                        ],
                                      );
                                    },
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(color: Color(0xFF0F5D55)),
                                    ),
                                    error: (err, stack) => Center(
                                      child: Text(
                                        'Error loading chart: $err',
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1.5,
                          shadowColor: Colors.black12,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Revenue Generated',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildChartMenu(context, 'Total Revenue Generated'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildDynamicRevenueHeader(state.monthlyRevenue),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 320,
                                  child: SfCartesianChart(
                                    enableAxisAnimation: false,
                                    primaryXAxis: CategoryAxis(
                                      labelRotation: 45,
                                      majorGridLines: const MajorGridLines(width: 0),
                                    ),
                                    primaryYAxis: NumericAxis(
                                      title: AxisTitle(
                                        text: 'Revenue (₹)',
                                        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                      numberFormat: NumberFormat.compact(),
                                      axisLine: const AxisLine(width: 0),
                                    ),
                                    tooltipBehavior: TooltipBehavior(enable: true),
                                    series: <ColumnSeries<_ChartData, String>>[
                                      ColumnSeries<_ChartData, String>(
                                        animationDuration: 0,
                                        dataSource: _getRevenueData(state.monthlyRevenue),
                                        xValueMapper: (data, _) => data.label,
                                        yValueMapper: (data, _) => data.value,
                                        pointColorMapper: (data, _) => data.color,
                                        dataLabelMapper: (data, _) => data.value > 0
                                            ? '₹${data.value.toStringAsFixed(2)}'
                                            : '₹0.00',
                                        dataLabelSettings: const DataLabelSettings(
                                          isVisible: true,
                                          showZeroValue: true,
                                          labelPosition: ChartDataLabelPosition.outside,
                                          textStyle: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 1.5,
                                shadowColor: Colors.black12,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Vehicle Distribution',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          _buildChartMenu(context, 'Vehicle Distribution'),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 360,
                                        child: missingCertificatesAsync.when(
                                          data: (data) {
                                            final chartData = [
                                              _ChartData('Fitness', data.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                                              _ChartData('Insurance', data.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                                              _ChartData('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                                              _ChartData('Permit', data.permitCertificateNotFound, const Color(0xFFD64D81)),
                                              _ChartData('Puc', data.pucCertificateNotFound, const Color(0xFF32353A)),
                                              _ChartData('Registration', data.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                                              _ChartData('All Clear', data.allClearNotFound, const Color(0xFF2FA85C)),
                                              _ChartData('Missing Data', data.weightCertificateNotFound, const Color(0xFFF5D671)),
                                            ];
                                            return SfCircularChart(
                                              legend: Legend(
                                                isVisible: true,
                                                overflowMode: LegendItemOverflowMode.wrap,
                                                position: LegendPosition.bottom,
                                                textStyle: const TextStyle(fontSize: 10),
                                              ),
                                              series: <DoughnutSeries<_ChartData, String>>[
                                                DoughnutSeries<_ChartData, String>(
                                                  animationDuration: 0,
                                                  dataSource: chartData,
                                                  xValueMapper: (data, _) => data.label,
                                                  yValueMapper: (data, _) => data.value,
                                                  pointColorMapper: (data, _) => data.color,
                                                  innerRadius: '60%',
                                                  dataLabelSettings: const DataLabelSettings(
                                                    isVisible: true,
                                                    labelPosition: ChartDataLabelPosition.outside,
                                                    textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                  dataLabelMapper: (data, _) => '${data.label}: ${data.value.toInt()}',
                                                ),
                                              ],
                                            );
                                          },
                                          loading: () => const Center(
                                            child: CircularProgressIndicator(color: Color(0xFF0F5D55)),
                                          ),
                                          error: (err, stack) => Center(
                                            child: Text(
                                              'Error loading chart: $err',
                                              style: const TextStyle(color: Colors.red, fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 1.5,
                                shadowColor: Colors.black12,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total Revenue Generated',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          _buildChartMenu(context, 'Total Revenue Generated'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildDynamicRevenueHeader(state.monthlyRevenue),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        height: 360,
                                        child: SfCartesianChart(
                                          enableAxisAnimation: false,
                                          primaryXAxis: CategoryAxis(
                                            labelRotation: 45,
                                            majorGridLines: const MajorGridLines(width: 0),
                                          ),
                                          primaryYAxis: NumericAxis(
                                            title: AxisTitle(
                                              text: 'Revenue (₹)',
                                              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                            numberFormat: NumberFormat.compact(),
                                            axisLine: const AxisLine(width: 0),
                                          ),
                                          tooltipBehavior: TooltipBehavior(enable: true),
                                          series: <ColumnSeries<_ChartData, String>>[
                                            ColumnSeries<_ChartData, String>(
                                              animationDuration: 0,
                                              dataSource: _getRevenueData(state.monthlyRevenue),
                                              xValueMapper: (data, _) => data.label,
                                              yValueMapper: (data, _) => data.value,
                                              pointColorMapper: (data, _) => data.color,
                                              dataLabelMapper: (data, _) => data.value > 0
                                                  ? '₹${data.value.toStringAsFixed(2)}'
                                                  : '₹0.00',
                                              dataLabelSettings: const DataLabelSettings(
                                                isVisible: true,
                                                showZeroValue: true,
                                                labelPosition: ChartDataLabelPosition.outside,
                                                textStyle: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ),
    ),
  );
}

  static Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    final String? safeValue = (value != null && options.contains(value))
        ? value
        : (options.isNotEmpty ? options.first : null);

    final keyString = '${hint}_${options.length}_$safeValue';
    return DropdownButtonFormField<String>(
      key: ValueKey(keyString),
      isExpanded: true,
      isDense: true,
      initialValue: safeValue,
      hint: Text(hint, style: const TextStyle(fontSize: 11)),
      style: const TextStyle(fontSize: 11, color: Colors.black87),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 6, right: 4),
          child: Icon(prefixIcon, color: const Color(0xFF0F5D55), size: 14),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 20),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 28), child: suffix)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDCECEC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDCECEC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0F5D55)),
        ),
      ),
      selectedItemBuilder: (BuildContext context) {
        return options.map<Widget>((String item) {
          String label = item;
          if (item == 'Select All District') {
            label = 'Select District';
          } else if (item == 'Select All Zone') {
            label = 'Select Zone';
          } else if (item == 'Select All Camera') {
            label = 'Select Camera';
          }
          return Text(
            label,
            style: const TextStyle(fontSize: 10.5, overflow: TextOverflow.ellipsis),
            maxLines: 1,
          );
        }).toList();
      },
      items: options
          .map(
            (option) {
              String label = option;
              if (option == 'Select All District') {
                label = 'Select District';
              } else if (option == 'Select All Zone') {
                label = 'Select Zone';
              } else if (option == 'Select All Camera') {
                label = 'Select Camera';
              }
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          )
          .toList(),
      onChanged: onChanged,
    );
  }
  static Widget _buildKeyMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    VoidCallback? onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 360;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isVerySmall ? 10 : 16,
            vertical: isVerySmall ? 10 : 14,
          ),
          child: Row(
            children: [
              Container(
                width: isVerySmall ? 40 : 48,
                height: isVerySmall ? 40 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isVerySmall ? 20 : 24,
                ),
              ),
              SizedBox(width: isVerySmall ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  List<_SummaryMetric> _getSummaryMetrics(Map<String, dynamic>? offenceData) {
    if (offenceData == null || offenceData.isEmpty) {
      return [
        const _SummaryMetric('Fitness', 0, 0, 0),
        const _SummaryMetric('Permit', 0, 0, 0),
        const _SummaryMetric('Road Tax', 0, 0, 0),
        const _SummaryMetric('Insurance', 0, 0, 0),
        const _SummaryMetric('PUC', 0, 0, 0),
        const _SummaryMetric('Registration', 0, 0, 0),
      ];
    }
    
    _SummaryMetric parseCertificate(String title, Map<String, dynamic>? cert) {
      final found = (cert?['certificateFound'] as num? ?? 0).toInt();
      final expired = (cert?['certificateExpired'] as num? ?? 0).toInt();
      final notFound = (cert?['certificateNotFound'] as num? ?? 0).toInt();
      return _SummaryMetric(title, found, expired, notFound);
    }

    return [
      parseCertificate('Fitness', offenceData['FITNESS_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('Permit', offenceData['PERMITTED_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('Road Tax', offenceData['ROAD_TAX_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('Insurance', offenceData['INSURANCE_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('PUC', offenceData['PUC_CERTIFICATE'] as Map<String, dynamic>?),
      parseCertificate('Registration', offenceData['REGISTRATION_CERTIFICATE'] as Map<String, dynamic>?),
    ];
  }



  List<_ChartData> _getRevenueData(Map<String, double> monthlyRevenue) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final colors = [
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2), // May
      const Color(0xFFED5C7D), // June
      const Color(0xFFE8D05C), // July
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
      const Color(0xFF7A7BF2),
    ];
    return List.generate(12, (index) {
      final m = months[index];
      final monthKey = (index + 1).toString();
      final val = monthlyRevenue[monthKey] ?? 0.0;
      return _ChartData(m, val, colors[index]);
    });
  }

  IconData _getMetricIcon(String title) {
    switch (title.toLowerCase()) {
      case 'fitness':
        return Icons.check_circle;
      case 'permit':
        return Icons.card_membership;
      case 'road tax':
        return Icons.currency_rupee;
      case 'insurance':
        return Icons.shield;
      case 'puc':
        return Icons.cloud;
      case 'registration':
        return Icons.description;
      default:
        return Icons.info;
    }
  }

  Color _getMetricBorderColor(String title) {
    switch (title.toLowerCase()) {
      case 'fitness':
        return const Color(0xFFED5C7D); // pink/red
      case 'permit':
        return const Color(0xFF7A7BF2); // purple
      case 'road tax':
        return const Color(0xFF0D9F8B); // teal/green
      case 'insurance':
        return const Color(0xFF3B82F6); // blue
      case 'puc':
        return const Color(0xFF0EA5E9); // light blue
      case 'registration':
        return const Color(0xFF991B1B); // dark red/purple
      default:
        return const Color(0xFFE2ECEC); // fallback
    }
  }

  Widget _buildComplianceCard(_SummaryMetric metric) {
    final List<_ChartData> chartData = [
      _ChartData('Compliant', metric.compliant, const Color(0xFF81D8B7)),
      _ChartData('Non-Compliant', metric.nonCompliant, const Color(0xFFE289A3)),
      _ChartData('Missing', metric.missing, const Color(0xFFF5D671)),
    ];

    final total = metric.compliant + metric.nonCompliant + metric.missing;
    final totalText = NumberFormat.decimalPattern().format(total);

    final isMobileLayout = MediaQuery.of(context).size.width < 750;

    final chartWidget = SizedBox(
      width: isMobileLayout ? 80 : double.infinity,
      height: isMobileLayout ? 80 : double.infinity,
      child: SfCircularChart(
        margin: EdgeInsets.zero,
        series: <DoughnutSeries<_ChartData, String>>[
          DoughnutSeries<_ChartData, String>(
            animationDuration: 500,
            dataSource: chartData,
            xValueMapper: (data, _) => data.label,
            yValueMapper: (data, _) => data.value,
            pointColorMapper: (data, _) => data.color,
            innerRadius: '70%',
            radius: '95%',
            dataLabelSettings: const DataLabelSettings(isVisible: false),
          ),
        ],
      ),
    );

    final infoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              metric.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3260),
              ),
            ),
            Icon(
              _getMetricIcon(metric.title),
              color: const Color(0xFF81D8B7),
              size: 18,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black38,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              totalText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildLegendRow('Compliant', metric.compliant, const Color(0xFF81D8B7)),
        const SizedBox(height: 4),
        _buildLegendRow('Non-Compliant', metric.nonCompliant, const Color(0xFFE289A3)),
        const SizedBox(height: 4),
        _buildLegendRow('${metric.title} Missing Data', metric.missing, const Color(0xFFF5D671)),
      ],
    );

    if (isMobileLayout) {
      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _getMetricBorderColor(metric.title), width: 1.5),
        ),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              chartWidget,
              const SizedBox(width: 14),
              Expanded(child: infoWidget),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getMetricBorderColor(metric.title), width: 1.5),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  metric.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3260),
                  ),
                ),
                Icon(
                  _getMetricIcon(metric.title),
                  color: const Color(0xFF81D8B7),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black38,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  totalText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: SfCircularChart(
                  margin: EdgeInsets.zero,
                  series: <DoughnutSeries<_ChartData, String>>[
                    DoughnutSeries<_ChartData, String>(
                      animationDuration: 500,
                      dataSource: chartData,
                      xValueMapper: (data, _) => data.label,
                      yValueMapper: (data, _) => data.value,
                      pointColorMapper: (data, _) => data.color,
                      innerRadius: '70%',
                      radius: '90%',
                      dataLabelSettings: const DataLabelSettings(isVisible: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendRow('Compliant', metric.compliant, const Color(0xFF81D8B7)),
            const SizedBox(height: 4),
            _buildLegendRow('Non-Compliant', metric.nonCompliant, const Color(0xFFE289A3)),
            const SizedBox(height: 4),
            _buildLegendRow('${metric.title} Missing Data', metric.missing, const Color(0xFFF5D671)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          NumberFormat.decimalPattern().format(value),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildChartMenu(BuildContext context, String chartTitle) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Color(0xFF666666), size: 20),
      tooltip: 'Chart context menu',
      onSelected: (value) {
        _exportChart(context, chartTitle, value);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'fullscreen',
          child: Text('View in full screen', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'png',
          child: Text('Download PNG image', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'jpeg',
          child: Text('Download JPEG image', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'pdf',
          child: Text('Download PDF document', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: 'svg',
          child: Text('Download SVG vector image', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }



  Widget _buildMobileLayout(
    BuildContext context,
    DashboardState state,
    DashboardNotifier notifier,
    AsyncValue<MissingCertificateModel> missingCertificatesAsync,
    double screenWidth,
  ) {
    final totalVehiclesVal = missingCertificatesAsync.maybeWhen(
      data: (data) => NumberFormat.decimalPattern().format(data.vehicleCount),
      orElse: () => '0',
    );

    final districtDropdown = _buildDropdownField(
      hint: _districtHint,
      value: _selectedDistrict,
      options: state.districts,
      onChanged: (value) async {
        setState(() {
          _selectedDistrict = value;
          _selectedZone = 'Select All Zone';
          _selectedCamera = 'Select All Camera';
        });
        if (value != null && value != 'Select All District') {
          final autoZone = await ref.read(dashboardNotifierProvider.notifier).fetchZonesForDistrict(value);
          if (autoZone != null && mounted) {
            setState(() => _selectedZone = autoZone);
            ref.read(dashboardNotifierProvider.notifier).fetchCamerasForZone(autoZone);
            ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
              district: value,
              zone: autoZone,
              camera: '',
              timeRange: _selectedTimeRange,
              customStartDate: _customStartDate,
              customEndDate: _customEndDate,
            );
            return;
          }
        } else {
          ref.read(dashboardNotifierProvider.notifier).resetZones();
        }
        ref.read(dashboardNotifierProvider.notifier).resetCameras();
        
        // Auto-apply
        ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
          district: value,
          zone: 'Select All Zone',
          camera: '',
          timeRange: _selectedTimeRange,
          customStartDate: _customStartDate,
          customEndDate: _customEndDate,
        );
      },
      prefixIcon: Icons.location_on_outlined,
    );

    final zoneDropdown = _buildDropdownField(
      hint: _zoneHint,
      value: _selectedZone,
      options: state.zones,
      onChanged: (value) {
        setState(() {
          _selectedZone = value;
          _selectedCamera = 'Select All Camera';
        });
        if (value != null && value != 'Select All Zone') {
          ref.read(dashboardNotifierProvider.notifier).fetchCamerasForZone(value);
        } else {
          ref.read(dashboardNotifierProvider.notifier).resetCameras();
        }
        
        // Auto-apply
        ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
          district: _selectedDistrict,
          zone: value,
          camera: '',
          timeRange: _selectedTimeRange,
        );
      },
      prefixIcon: Icons.location_city_outlined,
    );

    final cameraDropdown = _buildDropdownField(
      hint: _cameraHint,
      value: _selectedCamera,
      options: state.cameras,
      onChanged: (value) {
        setState(() {
          _selectedCamera = value;
        });
        final cameraID = state.cameraLocationToId[value];
        // Auto-apply
        ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
          district: _selectedDistrict,
          zone: _selectedZone,
          camera: cameraID,
          timeRange: _selectedTimeRange,
        );
      },
      prefixIcon: Icons.videocam_outlined,
    );

    final timeRangeDropdown = _buildDropdownField(
      hint: _timeRangeHint,
      value: _selectedTimeRange,
      options: _timeRangeOptions,
      onChanged: (value) {
        if (value == 'Custom') {
          _pickCustomDateRange(context);
        } else {
          setState(() {
            _selectedTimeRange = value;
            _customStartDate = null;
            _customEndDate = null;
          });
          final cameraID = state.cameraLocationToId[_selectedCamera];
          // Auto-apply
          ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
            district: _selectedDistrict,
            zone: _selectedZone,
            camera: cameraID,
            timeRange: value,
          );
        }
      },
      prefixIcon: Icons.calendar_today_outlined,
    );

    final metrics = _getSummaryMetrics(state.offenceData);
    final orderedTitles = ['Registration', 'Permit', 'Road Tax', 'Insurance', 'PUC', 'Fitness'];
    final Map<String, _SummaryMetric> metricMap = {
      for (var m in metrics) m.title: m
    };
    final orderedMetrics = orderedTitles
        .map((title) => metricMap[title])
        .whereType<_SummaryMetric>()
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -16,
                right: -16,
                top: -12,
                child: ClipPath(
                  clipper: HeaderCurveClipper(),
                  child: Container(
                    height: 130,
                    color: const Color(0xFF0F5D55),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildMobileTotalVehiclesCard(context, totalVehiclesVal),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3260),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _showOverviewFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: const Color(0xFF13A89E),
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _showOverviewFilters = !_showOverviewFilters;
                    // Restart/Reset all selected filters to default values
                    _selectedDistrict = 'Select All District';
                    _selectedZone = 'Select All Zone';
                    _selectedCamera = 'Select All Camera';
                    _selectedTimeRange = 'Today';
                    
                    ref.read(dashboardNotifierProvider.notifier).resetZones();
                    ref.read(dashboardNotifierProvider.notifier).resetCameras();
                    
                    ref.read(dashboardNotifierProvider.notifier).fetchDashboard(
                      district: 'Select All District',
                      zone: 'Select All Zone',
                      camera: '',
                      timeRange: 'Today',
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_showOverviewFilters) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE5ECEC),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    SizedBox(width: 140, child: districtDropdown),
                    const SizedBox(width: 6),
                    SizedBox(width: 140, child: zoneDropdown),
                    const SizedBox(width: 6),
                    SizedBox(width: 140, child: cameraDropdown),
                    const SizedBox(width: 6),
                    SizedBox(width: 140, child: timeRangeDropdown),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOverviewStatCard(
                  title: 'E-Challan',
                  value: state.eChallan,
                  icon: Icons.receipt_long,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9F8B), Color(0xFF10B998)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  trend: (int.tryParse(state.eChallan) ?? 0) > 0 ? '↑ Active Fines' : '— No Change',
                  onTap: () {
                    _showChallanDetailsModal(
                      context,
                      ref,
                      title: 'e-Challan',
                      challanTypes: const ["RAISE", "ECHALLAN", "E_CHALLAN"],
                    );
                  },
                ),
                const SizedBox(width: 12),
                _buildOverviewStatCard(
                  title: 'Manual Challan',
                  value: state.manualChallan,
                  icon: Icons.payments,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  trend: (int.tryParse(state.manualChallan) ?? 0) > 0 ? '↑ Collected Fines' : '— No Change',
                  onTap: () {
                    _showChallanDetailsModal(
                      context,
                      ref,
                      title: 'Manual Challan',
                      challanTypes: const ["COLLECT", "MANUAL"],
                    );
                  },
                ),
                const SizedBox(width: 12),
                _buildOverviewStatCard(
                  title: 'Vehicles Seized',
                  value: state.seizedVehicles,
                  icon: Icons.block,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBE123C), Color(0xFFE11D48)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  trend: (int.tryParse(state.seizedVehicles) ?? 0) > 0 ? '↑ Seized Vehicles' : '— No Change',
                  onTap: () {
                    _showChallanDetailsModal(
                      context,
                      ref,
                      title: 'Vehicles Seized',
                      challanTypes: const ["SEIZE", "SEIZED"],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Compliance Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3260),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: orderedMetrics.map((metric) => _buildComplianceRow(context, metric)).toList(),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vehicle Distribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3260),
                ),
              ),
              _buildChartMenu(context, 'Vehicle Distribution'),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _vehicleDistChartKey,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 1,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 150,
                      child: missingCertificatesAsync.when(
                        data: (data) {
                          final chartData = [
                            _ChartData('Fitness', data.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                            _ChartData('Insurance', data.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                            _ChartData('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                            _ChartData('Permit', data.permitCertificateNotFound, const Color(0xFFD64D81)),
                            _ChartData('Puc', data.pucCertificateNotFound, const Color(0xFF32353A)),
                            _ChartData('Registration', data.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                            _ChartData('All Clear', data.allClearNotFound, const Color(0xFF2FA85C)),
                            _ChartData('Missing Data', data.weightCertificateNotFound, const Color(0xFFF5D671)),
                          ];
                          return SfCircularChart(
                            margin: EdgeInsets.zero,
                            annotations: <CircularChartAnnotation>[
                              CircularChartAnnotation(
                                widget: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      NumberFormat.decimalPattern().format(data.vehicleCount),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F3260),
                                      ),
                                    ),
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.black45,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            series: <DoughnutSeries<_ChartData, String>>[
                              DoughnutSeries<_ChartData, String>(
                                animationDuration: 0,
                                dataSource: chartData,
                                xValueMapper: (data, _) => data.label,
                                yValueMapper: (data, _) => data.value,
                                pointColorMapper: (data, _) => data.color,
                                innerRadius: '60%',
                                dataLabelSettings: const DataLabelSettings(isVisible: false),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: Color(0xFF0F5D55)),
                        ),
                        error: (err, stack) => Center(
                          child: Text(
                            'Error: $err',
                            style: const TextStyle(color: Colors.red, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: missingCertificatesAsync.maybeWhen(
                      data: (data) {
                        final items = [
                          _buildDistributionRow('Insurance', data.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                          _buildDistributionRow('Road Tax', data.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                          _buildDistributionRow('PUC', data.pucCertificateNotFound, const Color(0xFF32353A)),
                          _buildDistributionRow('Registration', data.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                          _buildDistributionRow('Permit', data.permitCertificateNotFound, const Color(0xFFD64D81)),
                          _buildDistributionRow('Fitness', data.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                          _buildDistributionRow('Missing Data', data.weightCertificateNotFound, const Color(0xFFF5D671)),
                        ];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: items,
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Revenue Generated',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3260),
                ),
              ),
              _buildChartMenu(context, 'Total Revenue Generated'),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _revenueChartKey,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 1,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDynamicRevenueHeader(state.monthlyRevenue),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: SfCartesianChart(
                      enableAxisAnimation: false,
                      margin: EdgeInsets.zero,
                      primaryXAxis: CategoryAxis(
                        labelRotation: 0,
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: const TextStyle(fontSize: 8.5),
                      ),
                      primaryYAxis: NumericAxis(
                        title: AxisTitle(
                          text: 'Revenue (₹)',
                          textStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                        numberFormat: NumberFormat.compact(),
                        axisLine: const AxisLine(width: 0),
                        labelStyle: const TextStyle(fontSize: 8.5),
                      ),
                      series: <ColumnSeries<_ChartData, String>>[
                        ColumnSeries<_ChartData, String>(
                          animationDuration: 0,
                          dataSource: _getRevenueData(state.monthlyRevenue),
                          xValueMapper: (data, _) => data.label,
                          yValueMapper: (data, _) => data.value,
                          pointColorMapper: (data, _) => data.color,
                          dataLabelMapper: (data, _) => data.value > 0
                              ? '₹${data.value.toStringAsFixed(1)}'
                              : '₹0.0',
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            showZeroValue: false,
                            labelPosition: ChartDataLabelPosition.outside,
                            textStyle: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMobileTotalVehiclesCard(BuildContext context, String vehicleCount) {
    return Stack(
      children: [
        // Background container with gradient only
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3A34), Color(0xFF0F5D55)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                        SizedBox(width: 6),
                        Text(
                          'LIVE FEED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Last Updated: ${DateFormat('d MMM, HH:mm:ss').format(_lastUpdatedTime)} IST',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Vehicles',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicleCount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Across Telangana',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
    // Positioned background image of map and Charminar
    Positioned(
      right: 0,
      bottom: 0,
      top: 0,
      width: 180,
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Opacity(
            opacity: 0.45,
            child: Image.asset(
              'assets/images/vehicles_bg.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
            ),
          ),
        ),
      ),
    ),
  ],
);
}

  Widget _buildOverviewStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    required String trend,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          width: 125,
          height: 140,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  trend,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMetricColor(String title) {
    switch (title.toLowerCase()) {
      case 'registration':
        return const Color(0xFF16A34A);
      case 'permit':
        return const Color(0xFF8B5CF6);
      case 'road tax':
        return const Color(0xFFEC4899);
      case 'insurance':
        return const Color(0xFF3B82F6);
      case 'puc':
        return const Color(0xFFF59E0B);
      case 'fitness':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildComplianceRow(BuildContext context, _SummaryMetric metric) {
    final title = metric.title;
    final total = metric.compliant + metric.nonCompliant + metric.missing;
    final color = _getMetricColor(title);
    final icon = _getMetricIcon(title);
    final bgColor = color.withValues(alpha: 0.12);
    final isExpanded = _expandedComplianceCategory == title;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedComplianceCategory = isExpanded ? null : title;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5ECEC), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  // 1. Color-coded Icon Box
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  // 2. Metric Title
                  Expanded(
                    flex: 4,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F3260),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 3. Total Value
                  Expanded(
                    flex: 4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            NumberFormat.decimalPattern().format(total),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F3260),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 4. Vertical Divider
                  Container(
                    height: 20,
                    width: 1,
                    color: const Color(0xFFE5ECEC),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  // 5. Compliant, Non-Compliant, Missing Data columns
                  Expanded(
                    flex: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricDetailColumn(metric.compliant, 'Compliant', const Color(0xFF16A34A)),
                        _buildMetricDetailColumn(metric.nonCompliant, 'Non-Compliant', const Color(0xFFDC2626)),
                        _buildMetricDetailColumn(metric.missing, 'Missing Data', const Color(0xFFEA580C)),
                      ],
                    ),
                  ),
                  // 6. Keyboard chevron arrow
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.black38,
                    size: 16,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE5ECEC)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // circular chart
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: SfCircularChart(
                        margin: EdgeInsets.zero,
                        series: <DoughnutSeries<_ChartData, String>>[
                          DoughnutSeries<_ChartData, String>(
                            animationDuration: 300,
                            dataSource: [
                              _ChartData('Compliant', metric.compliant, const Color(0xFF16A34A)),
                              _ChartData('Non-Compliant', metric.nonCompliant, const Color(0xFFDC2626)),
                              _ChartData('Missing', metric.missing, const Color(0xFFEA580C)),
                            ],
                            xValueMapper: (data, _) => data.label,
                            yValueMapper: (data, _) => data.value,
                            pointColorMapper: (data, _) => data.color,
                            innerRadius: '65%',
                            radius: '100%',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendRow('Compliant', metric.compliant, const Color(0xFF16A34A)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Non-Compliant', metric.nonCompliant, const Color(0xFFDC2626)),
                          const SizedBox(height: 4),
                          _buildLegendRow('Missing Data', metric.missing, const Color(0xFFEA580C)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricDetailColumn(int value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NumberFormat.decimalPattern().format(value),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 7.0,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDistributionRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            NumberFormat.decimalPattern().format(value),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicRevenueHeader(Map<String, double> monthlyRevenue) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    final currentMonthIdx = now.month; // 1..12
    final prevMonthIdx = currentMonthIdx > 1 ? currentMonthIdx - 1 : 12;

    final currentVal = monthlyRevenue[currentMonthIdx.toString()] ?? 0.0;
    final prevVal = monthlyRevenue[prevMonthIdx.toString()] ?? 0.0;

    String highestMonthName = months[currentMonthIdx - 1];
    double highestVal = 0.0;
    monthlyRevenue.forEach((key, val) {
      if (val > highestVal) {
        highestVal = val;
        final mInt = int.tryParse(key);
        if (mInt != null && mInt >= 1 && mInt <= 12) {
          highestMonthName = months[mInt - 1];
        }
      }
    });

    String formatAmt(double amt) {
      if (amt >= 10000000) {
        return '₹ ${(amt / 10000000).toStringAsFixed(2)} Cr';
      } else if (amt >= 100000) {
        return '₹ ${(amt / 100000).toStringAsFixed(2)} L';
      } else if (amt >= 1000) {
        return '₹ ${(amt / 1000).toStringAsFixed(1)} K';
      } else {
        return '₹ ${amt.toStringAsFixed(0)}';
      }
    }

    final curLabel = '${months[currentMonthIdx - 1]} (Current)';
    final highLabel = '$highestMonthName (Highest)';
    final prevLabel = '${months[prevMonthIdx - 1]} (Previous)';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRevenueIndicator(formatAmt(currentVal), curLabel, const Color(0xFF7A7BF2)),
        _buildRevenueIndicator(formatAmt(highestVal), highLabel, const Color(0xFFED5C7D)),
        _buildRevenueIndicator(formatAmt(prevVal), prevLabel, const Color(0xFF2FA85C)),
      ],
    );
  }

  Widget _buildRevenueIndicator(String amount, String period, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          period,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _exportChart(BuildContext context, String title, String format) async {
    if (format == 'fullscreen') {
      final state = ref.read(dashboardNotifierProvider);
      final params = MissingCertificatesParams(
        district: _selectedDistrict,
        zone: _selectedZone,
        camera: state.cameraLocationToId[_selectedCamera],
      );
      final certificatesAsync = ref.read(missingCertificatesProvider(params));
      final certificates = certificatesAsync.value;

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3260),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (title == 'Vehicle Distribution') ...[
                    if (certificates != null) ...[
                      SizedBox(
                        height: 300,
                        child: SfCircularChart(
                          legend: Legend(
                            isVisible: true,
                            position: LegendPosition.bottom,
                            overflowMode: LegendItemOverflowMode.wrap,
                          ),
                          series: <DoughnutSeries<_ChartData, String>>[
                            DoughnutSeries<_ChartData, String>(
                              dataSource: [
                                _ChartData('Fitness', certificates.fitnessCertificateNotFound, const Color(0xFFE28B5C)),
                                _ChartData('Insurance', certificates.insuranceCertificateNotFound, const Color(0xFF5CA0F2)),
                                _ChartData('Road Tax', certificates.roadTaxCertificateNotFound, const Color(0xFF7A7BF2)),
                                _ChartData('Permit', certificates.permitCertificateNotFound, const Color(0xFFD64D81)),
                                _ChartData('Puc', certificates.pucCertificateNotFound, const Color(0xFF32353A)),
                                _ChartData('Registration', certificates.registrationCertificateNotFound, const Color(0xFFE8D05C)),
                                _ChartData('All Clear', certificates.allClearNotFound, const Color(0xFF2FA85C)),
                                _ChartData('Missing Data', certificates.weightCertificateNotFound, const Color(0xFFF5D671)),
                              ],
                              xValueMapper: (data, _) => data.label,
                              yValueMapper: (data, _) => data.value,
                              pointColorMapper: (data, _) => data.color,
                              innerRadius: '60%',
                              radius: '95%',
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelPosition: ChartDataLabelPosition.outside,
                                textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                              dataLabelMapper: (data, _) => '${data.label}: ${data.value.toInt()}',
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Center(child: Text('No data loaded')),
                    ],
                  ] else ...[
                    // Total Revenue Generated
                    RepaintBoundary(
                      key: _revenueChartKey,
                      child: SizedBox(
                        height: 300,
                        child: SfCartesianChart(
                          primaryXAxis: CategoryAxis(majorGridLines: const MajorGridLines(width: 0)),
                          primaryYAxis: NumericAxis(
                            numberFormat: NumberFormat.compact(),
                            axisLine: const AxisLine(width: 0),
                          ),
                          series: <ColumnSeries<_ChartData, String>>[
                            ColumnSeries<_ChartData, String>(
                              dataSource: _getRevenueData(state.monthlyRevenue),
                              xValueMapper: (data, _) => data.label,
                              yValueMapper: (data, _) => data.value,
                              pointColorMapper: (data, _) => data.color,
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelPosition: ChartDataLabelPosition.outside,
                                textStyle: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    try {
      final key = (title == 'Vehicle Distribution') ? _vehicleDistChartKey : _revenueChartKey;
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chart element not ready for export'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final sanitizeTitle = title.replaceAll(RegExp(r'[/\\:\s]'), '_');
      final extension = (format == 'jpeg') ? 'jpg' : format;
      final fileName = '${sanitizeTitle}_chart.$extension';

      await PdfHelper.displayOrDownloadPdf(pngBytes, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F5D55),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Exported $title chart as ${format.toUpperCase()} successfully.',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting chart image: $e');
    }
  }

  void _showChallanDetailsModal(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<String> challanTypes,
  }) {
    final repo = ref.read(dashboardNotifierProvider.notifier).repository;

    String searchQuery = '';
    int currentPage = 1;
    const int pageSize = 10;
    bool isLoading = true;
    List<Map<String, dynamic>> allRecords = [];
    String? errorMessage;
    Map<String, bool> pdfLoadingMap = {};

    final String district = _selectedDistrict ?? '';
    final String zone = _selectedZone ?? '';
    final String camera = _selectedCamera ?? '';

    final now = DateTime.now();
    final String todayStr = '${now.month}/${now.day}/${now.year.toString().substring(2)}';

    Map<String, dynamic>? selectedPdfRecord;
    dynamic selectedPdfData;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final mediaQuery = MediaQuery.of(context);
            final bool isMobile = mediaQuery.size.width < 600;

            if (selectedPdfRecord != null) {
              final rec = selectedPdfRecord!;
              final vcr = (rec['vcrNumber'] ?? 'N/A').toString();
              final vehicleNo = (rec['registrationNumber'] ?? rec['vehicleNumber'] ?? 'N/A').toString();
              final offences = (rec['offences'] ?? 'N/A').toString();
              final fine = (rec['fineAmount'] as num? ?? 0.0).toDouble();

              return Dialog(
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 550),
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Nav
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedPdfRecord = null;
                                  selectedPdfData = null;
                                });
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.arrow_back, size: 18, color: Color(0xFF1D4ED8)),
                                  SizedBox(width: 4),
                                  Text('Back to List', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 12),

                        // Title Bar
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B998).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.picture_as_pdf, color: Color(0xFF10B998), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VCR Receipt PDF',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E2A5E),
                                  ),
                                ),
                                Text(
                                  vcr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Details Card
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildReceiptDetailRow('VCR Number', vcr, isBold: true, valueColor: const Color(0xFF1D4ED8)),
                              const Divider(height: 16, color: Color(0xFFF1F5F9)),
                              _buildReceiptDetailRow('Vehicle No', vehicleNo, isBold: true),
                              const Divider(height: 16, color: Color(0xFFF1F5F9)),
                              _buildReceiptDetailRow('Offences', offences, isBold: true, valueColor: const Color(0xFFEF4444)),
                              const Divider(height: 16, color: Color(0xFFF1F5F9)),
                              _buildReceiptDetailRow('Fine Amount', '₹${fine.toStringAsFixed(2)}', isBold: true),
                              const Divider(height: 16, color: Color(0xFFF1F5F9)),
                              _buildReceiptDetailRow('Status', 'PDF Generated & Saved', valueColor: const Color(0xFF10B998)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await PdfHelper.displayOrDownloadPdf(selectedPdfData, '$vcr.pdf', openViewer: true);
                                },
                                icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
                                label: const Text('Open / Download PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF192A68),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedPdfRecord = null;
                                  selectedPdfData = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Back', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (isLoading && allRecords.isEmpty && errorMessage == null) {
              repo.fetchChallanDetails(
                challanTypes: challanTypes,
                districtName: district,
                zoneName: zone,
                cameraId: camera,
              ).then((data) {
                setModalState(() {
                  allRecords = data;
                  isLoading = false;
                });
              }).catchError((err) {
                setModalState(() {
                  errorMessage = err.toString();
                  isLoading = false;
                });
              });
            }

            final filteredRecords = allRecords.where((rec) {
              if (searchQuery.trim().isEmpty) return true;
              final q = searchQuery.toLowerCase().trim();
              final vcr = (rec['vcrNumber'] ?? '').toString().toLowerCase();
              final vehicle = (rec['registrationNumber'] ?? rec['vehicleNumber'] ?? '').toString().toLowerCase();
              final offences = (rec['offences'] ?? '').toString().toLowerCase();
              return vcr.contains(q) || vehicle.contains(q) || offences.contains(q);
            }).toList();

            final int totalItems = filteredRecords.length;
            final int totalPages = (totalItems / pageSize).ceil() == 0 ? 1 : (totalItems / pageSize).ceil();
            if (currentPage > totalPages) currentPage = totalPages;

            final int startIndex = totalItems == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
            final int endIndex = ((currentPage * pageSize) > totalItems) ? totalItems : (currentPage * pageSize);

            final pageRecords = filteredRecords.skip((currentPage - 1) * pageSize).take(pageSize).toList();

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$title Details',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E2A5E),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),

                      // Filter Subheader
                      if (isMobile) ...[
                        Text(
                          '| From: $todayStr To: $todayStr',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: TextField(
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [UpperCaseTextFormatter()],
                            onChanged: (val) {
                              setModalState(() {
                                searchQuery = val.toUpperCase();
                                currentPage = 1;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search vehicle or VCR...',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Color(0xFF192A68)),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '| From: $todayStr To: $todayStr',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            SizedBox(
                              width: 240,
                              height: 36,
                              child: TextField(
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [UpperCaseTextFormatter()],
                                onChanged: (val) {
                                  setModalState(() {
                                    searchQuery = val.toUpperCase();
                                    currentPage = 1;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search vehicle or VCR...',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                  prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: Color(0xFF192A68)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Data Table Container (with horizontal scroll for mobile)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 700),
                              child: Column(
                                children: [
                                  // Dark Navy Header Row
                                  Container(
                                    color: const Color(0xFF192A68),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                    child: const Row(
                                      children: [
                                        SizedBox(
                                          width: 45,
                                          child: Text('S.No', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                                        ),
                                        SizedBox(
                                          width: 170,
                                          child: Text('VCR Number', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                        SizedBox(
                                          width: 120,
                                          child: Text('Vehicle No', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                        SizedBox(
                                          width: 180,
                                          child: Text('Offences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                        SizedBox(
                                          width: 100,
                                          child: Text('Fine Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                        SizedBox(
                                          width: 110,
                                          child: Text('Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Table Body
                                  if (isLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(40),
                                      child: Center(child: CircularProgressIndicator(color: Color(0xFF192A68))),
                                    )
                                  else if (errorMessage != null)
                                    Padding(
                                      padding: const EdgeInsets.all(30),
                                      child: Center(child: Text('Error loading data: $errorMessage', style: const TextStyle(color: Colors.red))),
                                    )
                                  else if (pageRecords.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(30),
                                      child: Center(child: Text('No records found', style: TextStyle(color: Colors.grey, fontSize: 14))),
                                    )
                                  else
                                    Column(
                                      children: List.generate(pageRecords.length, (index) {
                                        final item = pageRecords[index];
                                        final sNo = startIndex + index;
                                        final vcr = (item['vcrNumber'] ?? 'N/A').toString();
                                        final vehicleNo = (item['registrationNumber'] ?? item['vehicleNumber'] ?? 'N/A').toString();
                                        final offences = (item['offences'] ?? 'N/A').toString();
                                        final fine = (item['fineAmount'] as num? ?? 0.0).toDouble();
                                        final bool isGeneratingPdf = pdfLoadingMap[vcr] ?? false;

                                        return Container(
                                          color: index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 45,
                                                child: Text('$sNo', style: const TextStyle(fontSize: 13, color: Color(0xFF475569)), textAlign: TextAlign.center),
                                              ),
                                              SizedBox(
                                                width: 170,
                                                child: Text(
                                                  vcr,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 120,
                                                child: Text(
                                                  vehicleNo,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 180,
                                                child: Text(
                                                  offences,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 100,
                                                child: Text(
                                                  '₹${fine.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 110,
                                                child: OutlinedButton(
                                                  onPressed: isGeneratingPdf
                                                      ? null
                                                      : () async {
                                                          setModalState(() {
                                                            pdfLoadingMap[vcr] = true;
                                                          });
                                                          try {
                                                            final pdfData = await repo.generatePdf(vcr);
                                                            setModalState(() {
                                                              pdfLoadingMap[vcr] = false;
                                                              selectedPdfRecord = item;
                                                              selectedPdfData = pdfData;
                                                            });
                                                            await PdfHelper.displayOrDownloadPdf(pdfData, '$vcr.pdf');
                                                          } catch (err) {
                                                            setModalState(() {
                                                              pdfLoadingMap[vcr] = false;
                                                            });
                                                          }
                                                        },
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFF3B82F6)),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                  ),
                                                  child: isGeneratingPdf
                                                      ? const SizedBox(
                                                          width: 14,
                                                          height: 14,
                                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                                                        )
                                                      : const Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(Icons.picture_as_pdf, size: 13, color: Color(0xFF3B82F6)),
                                                            SizedBox(width: 4),
                                                            Text('View PDF', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Footer Row
                      if (isMobile) ...[
                        Center(
                          child: Text(
                            'Showing $startIndex to $endIndex of $totalItems entries',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: currentPage > 1
                                  ? () {
                                      setModalState(() {
                                        currentPage--;
                                      });
                                    }
                                  : null,
                              child: const Text('« Previous', style: TextStyle(fontSize: 12)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF009688),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('$currentPage', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            TextButton(
                              onPressed: currentPage < totalPages
                                  ? () {
                                      setModalState(() {
                                        currentPage++;
                                      });
                                    }
                                  : null,
                              child: const Text('Next »', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing $startIndex to $endIndex of $totalItems entries',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: currentPage > 1
                                      ? () {
                                          setModalState(() {
                                            currentPage--;
                                          });
                                        }
                                      : null,
                                  child: const Text('« Previous', style: TextStyle(fontSize: 12)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF009688),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('$currentPage', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                TextButton(
                                  onPressed: currentPage < totalPages
                                      ? () {
                                          setModalState(() {
                                            currentPage++;
                                          });
                                        }
                                      : null,
                                  child: const Text('Next »', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReceiptDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? const Color(0xFF1E293B),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

}


class _SummaryMetric {
  const _SummaryMetric(
    this.title,
    this.compliant,
    this.nonCompliant,
    this.missing,
  );

  final String title;
  final int compliant;
  final int nonCompliant;
  final int missing;
}

class _ChartData {
  const _ChartData(this.label, this.value, this.color);

  final String label;
  final num value;
  final Color color;
}

class _LiveFeedClock extends StatefulWidget {
  const _LiveFeedClock();

  @override
  State<_LiveFeedClock> createState() => _LiveFeedClockState();
}

class _LiveFeedClockState extends State<_LiveFeedClock> {
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCECEC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.red, size: 8),
          const SizedBox(width: 8),
          const Text(
            'LIVE FEED',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${DateFormat('d MMM, HH:mm:ss').format(_currentTime)} IST',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.lineTo(0, 40);
    path.quadraticBezierTo(size.width / 2, 140, size.width, 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
