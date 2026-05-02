import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';

// ─────────────────────────────────────────
// Data model
// ─────────────────────────────────────────
class MosqueModel {
  final int id;
  final String name;
  final LatLng location;
  final double? distance; // metres

  const MosqueModel({
    required this.id,
    required this.name,
    required this.location,
    this.distance,
  });

  factory MosqueModel.fromOverpass(Map<String, dynamic> element, LatLng? userPos) {
    final lat = (element['lat'] as num?)?.toDouble() ??
        (element['center']?['lat'] as num?)?.toDouble() ??
        0.0;
    final lon = (element['lon'] as num?)?.toDouble() ??
        (element['center']?['lon'] as num?)?.toDouble() ??
        0.0;
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final name = (tags['name:ar'] as String?) ??
        (tags['name'] as String?) ??
        'مسجد';

    double? dist;
    if (userPos != null) {
      dist = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        lat,
        lon,
      );
    }

    return MosqueModel(
      id: element['id'] as int,
      name: name,
      location: LatLng(lat, lon),
      distance: dist,
    );
  }

  String get distanceLabel {
    if (distance == null) return '';
    if (distance! < 1000) return '${distance!.toStringAsFixed(0)} م';
    return '${(distance! / 1000).toStringAsFixed(1)} كم';
  }
}

// ─────────────────────────────────────────
// Page
// ─────────────────────────────────────────
class NearbyMosquesPage extends StatefulWidget {
  const NearbyMosquesPage({super.key});

  @override
  State<NearbyMosquesPage> createState() => _NearbyMosquesPageState();
}

class _NearbyMosquesPageState extends State<NearbyMosquesPage>
    with SingleTickerProviderStateMixin {
  // State
  LatLng? _userLocation;
  List<MosqueModel> _mosques = [];
  MosqueModel? _selected;
  bool _loading = false;
  String? _error;
  double _radiusKm = 1.5; // default search radius

  // Map — guard moves until FlutterMap has rendered at least once
  final MapController _mapController = MapController();
  bool _mapReady = false;

  // Bottom sheet
  late AnimationController _sheetAnim;
  late Animation<double> _sheetSlide;

  // Tab: map / list
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    _sheetAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sheetSlide = CurvedAnimation(parent: _sheetAnim, curve: Curves.easeOut);
    _initLocation();
  }

  @override
  void dispose() {
    _sheetAnim.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────
  Future<void> _initLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'خدمة الموقع غير مفعّلة. يرجى تفعيل GPS من الإعدادات.';
          _loading = false;
        });
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _error = 'تم رفض إذن الموقع بشكل دائم. يرجى تفعيله من الإعدادات.';
          _loading = false;
        });
        return;
      }
      if (perm == LocationPermission.denied) {
        setState(() {
          _error = 'لم يتم منح إذن الموقع.';
          _loading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
      });

      if (_mapReady && _userLocation != null) {
        _mapController.move(_userLocation!, 14);
      }

      await _fetchMosques();
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ أثناء الحصول على الموقع: $e';
        _loading = false;
      });
    }
  }

  // ── Overpass ──────────────────────────────
  Future<void> _fetchMosques() async {
    if (_userLocation == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _mosques = [];
      _selected = null;
    });

    final lat = _userLocation!.latitude;
    final lon = _userLocation!.longitude;
    final rad = (_radiusKm * 1000).toInt();

    // Very broad query — no religion filter.
    // In Egypt & MENA, place_of_worship is almost always a mosque.
    final query =
        '[out:json][timeout:30];'
        '('
        'nwr["amenity"="place_of_worship"](around:$rad,$lat,$lon);'
        'nwr["building"="mosque"](around:$rad,$lat,$lon);'
        ');out center;';

    // Try multiple Overpass endpoints (main + mirrors)
    final endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    ];

    for (final endpoint in endpoints) {
      try {
        final url = Uri.parse('$endpoint?data=${Uri.encodeComponent(query)}');
        debugPrint('🕌 Overpass request: lat=$lat, lon=$lon, radius=${rad}m');
        debugPrint('🕌 Trying: $endpoint');

        final resp = await http.get(
          url,
          headers: {
            'User-Agent': 'NiyyahTracker/1.1 (Flutter; Android)',
            'Accept': '*/*',
          },
        ).timeout(const Duration(seconds: 25));

        debugPrint('🕌 Response status: ${resp.statusCode}');

        if (resp.statusCode != 200) {
          debugPrint('🕌 Response body: ${resp.body.substring(0, (resp.body.length).clamp(0, 500))}');
          continue; // try next endpoint
        }

        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final elements = json['elements'] as List<dynamic>? ?? [];
        debugPrint('🕌 Found ${elements.length} elements');

        final mosques = elements
            .map((e) => MosqueModel.fromOverpass(e as Map<String, dynamic>, _userLocation))
            .where((m) => m.location.latitude != 0.0 && m.location.longitude != 0.0)
            .toList()
          ..sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));

        // Remove duplicates by ID
        final seen = <int>{};
        mosques.retainWhere((m) => seen.add(m.id));

        debugPrint('🕌 After filter: ${mosques.length} mosques');

        setState(() {
          _mosques = mosques;
          _loading = false;
        });

        if (mosques.isEmpty) {
          setState(() => _error = 'لم يتم العثور على مساجد في نطاق ${_radiusKm.toStringAsFixed(1)} كم.\nجرّب زيادة النطاق.');
        }
        return; // success — stop trying endpoints
      } catch (e) {
        debugPrint('🕌 Error with $endpoint: $e');
        continue;
      }
    }

    // All endpoints failed
    setState(() {
      _error = 'تعذّر الاتصال بخادم المساجد. تحقق من اتصالك بالإنترنت.';
      _loading = false;
    });
  }


  // ── Select mosque ──────────────────────────
  void _selectMosque(MosqueModel m) {
    setState(() => _selected = m);
    if (_mapReady) _mapController.move(m.location, 16);
    _sheetAnim.forward();
  }

  void _clearSelection() {
    setState(() => _selected = null);
    _sheetAnim.reverse();
  }

  // ── Open in Maps ──────────────────────────
  Future<void> _openInMaps(MosqueModel m) async {
    final uri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${m.location.latitude}&mlon=${m.location.longitude}#map=17/${m.location.latitude}/${m.location.longitude}',
    );
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(),
            _buildControls(),
            Expanded(
              child: Stack(
                children: [
                  // Always render map so MapController initializes
                  if (!_showList) _buildMapView(),
                  if (_showList) _buildListView(),

                  // Loading overlay on top of map
                  if (_loading)
                    Container(
                      color: AppColors.background.withOpacity(0.85),
                      child: _buildLoader(),
                    ),

                  // Error overlay on top of map
                  if (!_loading && _error != null && _mosques.isEmpty)
                    Container(
                      color: AppColors.background.withOpacity(0.9),
                      child: _buildError(),
                    ),

                  // Mosque detail sheet
                  if (_selected != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(_sheetSlide),
                        child: _buildDetailSheet(_selected!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _userLocation != null && !_loading && !_showList
            ? FloatingActionButton.small(
                backgroundColor: AppColors.darkGreen,
                foregroundColor: Colors.white,
                tooltip: 'موقعي',
                onPressed: () {
                  if (_mapReady && _userLocation != null) {
                    _mapController.move(_userLocation!, 14);
                  }
                },
                child: const Icon(Icons.my_location),
              )
            : null,
      ),
    );
  }

  // ── Header ───────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                ),
              ),
              Flexible(
                child: Text(
                  '🕌 المساجد القريبة',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              // Map / List toggle
              _ToggleChip(
                active: !_showList,
                icon: Icons.map_outlined,
                label: 'خريطة',
                onTap: () => setState(() {
                  _showList = false;
                  _clearSelection();
                }),
              ),
              const SizedBox(width: 8),
              _ToggleChip(
                active: _showList,
                icon: Icons.list_alt_outlined,
                label: 'قائمة',
                onTap: () => setState(() {
                  _showList = true;
                  _clearSelection();
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Controls ─────────────────────────────
  Widget _buildControls() {
    return Container(
      color: AppColors.darkGreen.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            'نطاق البحث:',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreen,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.darkGreen,
                thumbColor: AppColors.darkGreen,
                inactiveTrackColor: AppColors.paleGreen,
                overlayColor: AppColors.darkGreen.withOpacity(0.12),
                trackHeight: 4,
              ),
              child: Slider(
                value: _radiusKm,
                min: 0.5,
                max: 5,
                divisions: 9,
                label: '${_radiusKm.toStringAsFixed(1)} كم',
                onChanged: (v) => setState(() => _radiusKm = v),
                onChangeEnd: (_) => _fetchMosques(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.darkGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_radiusKm.toStringAsFixed(1)} كم',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.darkGreen),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _fetchMosques,
          ),
        ],
      ),
    );
  }

  // ── Map view ──────────────────────────────
  Widget _buildMapView() {
    final center = _userLocation ?? const LatLng(24.7136, 46.6753); // Riyadh fallback
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        onMapReady: () => setState(() => _mapReady = true),
        onTap: (_, __) => _clearSelection(),
      ),
      children: [
        // Tile layer — OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.niyyahtracker.app',
          maxZoom: 19,
        ),

        // User accuracy circle
        if (_userLocation != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _userLocation!,
                radius: 18,
                color: AppColors.darkGreen.withOpacity(0.15),
                borderColor: AppColors.darkGreen.withOpacity(0.6),
                borderStrokeWidth: 2,
              ),
            ],
          ),

        // Mosque markers
        MarkerLayer(
          markers: [
            // User dot
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 36,
                height: 36,
                child: _UserDot(),
              ),

            // Mosque pins
            ..._mosques.map(
              (m) => Marker(
                point: m.location,
                width: 52,
                height: 52,
                child: GestureDetector(
                  onTap: () => _selectMosque(m),
                  child: _MosquePin(
                    selected: _selected?.id == m.id,
                    label: m.distanceLabel,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── List view ─────────────────────────────
  Widget _buildListView() {
    if (_mosques.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🕌', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              'لا توجد مساجد في هذا النطاق',
              style: GoogleFonts.cairo(color: AppColors.gray, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _mosques.length,
      itemBuilder: (_, i) {
        final m = _mosques[i];
        return _MosqueListTile(
          mosque: m,
          index: i + 1,
          onTap: () {
            setState(() => _showList = false);
            Future.delayed(const Duration(milliseconds: 100), () => _selectMosque(m));
          },
          onNavigate: () => _openInMaps(m),
        );
      },
    );
  }

  // ── Loader ───────────────────────────────
  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.darkGreen),
          const SizedBox(height: 16),
          Text(
            'جارٍ البحث عن المساجد...',
            style: GoogleFonts.cairo(color: AppColors.gray, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: AppColors.gray, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initLocation,
              icon: const Icon(Icons.refresh),
              label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail sheet ──────────────────────────
  Widget _buildDetailSheet(MosqueModel m) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.paleGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text('🕌', style: TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.dark,
                      ),
                    ),
                    if (m.distanceLabel.isNotEmpty)
                      Text(
                        '📍 ${m.distanceLabel}',
                        style: GoogleFonts.cairo(
                          color: AppColors.midGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.gray),
                onPressed: _clearSelection,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.navigation_outlined,
                  label: 'الاتجاهات',
                  color: AppColors.darkGreen,
                  onTap: () => _openInMaps(m),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.location_on_outlined,
                  label: 'عرض على الخريطة',
                  color: AppColors.midGreen,
                  onTap: () {
                    _clearSelection();
                    setState(() => _showList = false);
                    Future.delayed(
                      const Duration(milliseconds: 200),
                      () => _selectMosque(m),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────

class _UserDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.darkGreen, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.darkGreen,
          ),
        ),
      ),
    );
  }
}

class _MosquePin extends StatelessWidget {
  final bool selected;
  final String label;
  const _MosquePin({required this.selected, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: selected ? 40 : 32,
          height: selected ? 40 : 32,
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : AppColors.darkGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (selected ? AppColors.gold : AppColors.darkGreen)
                    .withOpacity(0.45),
                blurRadius: selected ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Text('🕌', style: TextStyle(fontSize: 16)),
          ),
        ),
        if (label.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreen,
              ),
            ),
          ),
      ],
    );
  }
}

class _MosqueListTile extends StatelessWidget {
  final MosqueModel mosque;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onNavigate;

  const _MosqueListTile({
    required this.mosque,
    required this.index,
    required this.onTap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: AppColors.darkGreen.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Index badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.paleGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGreen,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mosque.name,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.dark,
                      ),
                    ),
                    if (mosque.distanceLabel.isNotEmpty)
                      Text(
                        '📍 ${mosque.distanceLabel}',
                        style: GoogleFonts.cairo(
                          color: AppColors.midGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              // Navigate button
              IconButton(
                icon: const Icon(Icons.navigation_outlined, color: AppColors.darkGreen),
                onPressed: onNavigate,
                tooltip: 'الاتجاهات',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? AppColors.darkGreen : Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.darkGreen : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
