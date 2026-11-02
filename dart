import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const RadioWorldApp());
}

class RadioWorldApp extends StatefulWidget {
  const RadioWorldApp({super.key});

  @override
  State<RadioWorldApp> createState() => _RadioWorldAppAppState();
}

class _RadioWorldAppAppState extends State<RadioWorldApp> {
  String _currentTheme = 'purple'; // الأوضاع المتاحة: purple, blue, dark

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('app_theme_mode') ?? 'purple';
    });
  }

  Future<void> _updateTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = themeName;
    });
    await prefs.setString('app_theme_mode', themeName);
  }

  Color _getPrimaryColor() {
    if (_currentTheme == 'blue') return Colors.blueAccent;
    if (_currentTheme == 'dark') return Colors.grey;
    return Colors.deepPurpleAccent;
  }

  @override
  Widget build(BuildContext context) {
    Color primaryColor = _getPrimaryColor();

    return MaterialApp(
      title: 'بث العالم التفاعلي الشامل',
      theme: ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: _currentTheme == 'dark' ? const Color(0xFF0A0A0A) : const Color(0xFF0D0B14),
      ),
      debugShowCheckedModeBanner: false,
      home: MainSelectionScreen(
        currentTheme: _currentTheme,
        onThemeChanged: _updateTheme,
      ),
    );
  }
}

// ==========================================
// 1. شاشة البدء الرئيسية والاختيار والـ VPN والإعدادات
// ==========================================
class MainSelectionScreen extends StatefulWidget {
  final String currentTheme;
  final Function(String) onThemeChanged;

  const MainSelectionScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<MainSelectionScreen> createState() => _MainSelectionScreenState();
}

class _MainSelectionScreenState extends State<MainSelectionScreen> {
  InterstitialAd? _interstitialAd;
  late OpenVPN _vpnEngine;
  bool _isVpnConnected = false;
  String _vpnStatus = "غير متصل";

  final String _ovpnConfig = '''
client
dev tun
proto udp
remote 219.100.37.246 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-128-CBC
auth SHA1
verb 3
<ca>
-----BEGIN CERTIFICATE-----
MIIEizCCA3OgAwIBAgIQN2W4p0v19lqG8NpxmH4WpDANBgkqhkiG9w0BAQsFADBT
...
-----END CERTIFICATE-----
</ca>
''';

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    _initVpnEngine();
  }

  void _initVpnEngine() {
    _vpnEngine = OpenVPN(
      onVpnStatusChanged: (data) {
        if (mounted) setState(() => _vpnStatus = data?.status ?? "مجهول");
      },
      onVpnStageChanged: (stage, raw) {
        if (mounted) setState(() => _isVpnConnected = (stage == VPNStage.connected));
      },
    );
    _vpnEngine.initialize(
      groupIdentifier: "group.com.worldradio.vpn",
      providerBundleIdentifier: "com.worldradio.vpn.VPNExtension",
    );
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => debugPrint('فشل تحميل الإعلان البيني: $error'),
      ),
    );
  }

  void _toggleVpn() {
    if (_isVpnConnected) {
      _vpnEngine.disconnect();
    } else {
      _vpnEngine.connect(_ovpnConfig, "Global Server", username: "vpn", password: "vpn");
    }
  }

  void _navigateToExplorer(bool isTvMode) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          _goToScreen(isTvMode);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _goToScreen(isTvMode);
        },
      );
      _interstitialAd!.show();
    } else {
      _goToScreen(isTvMode);
    }
  }

  void _goToScreen(bool isTvMode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainMapExplorerScreen(
          isTvMode: isTvMode,
          currentTheme: widget.currentTheme,
        ),
      ),
    );
  }

  // ميزة تحديد صورة شاشة البداية ديناميكياً من ملفاتك الجاهزة
  String _getSelectionBackgroundImage() {
    if (widget.currentTheme == 'blue') {
      return 'assets/radio_tv_day_loding.png'; // الصورة النهارية الفاتحة التي جهزتها
    }
    if (widget.currentTheme == 'dark') {
      return 'assets/radio_tv_night_background4.png'; // صورة الخلفية الليلية الداكنة الرابعة
    }
    return 'assets/radio_tv_night_loding.png'; // الصورة البنفسجية الافتراضية
  }

  Color _getThemeColor() {
    if (widget.currentTheme == 'blue') return Colors.blueAccent;
    if (widget.currentTheme == 'dark') return Colors.white70;
    return Colors.deepPurpleAccent;
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = _getThemeColor();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // عرض الصورة المحددة كخلفية كاملة للشاشة الترحيبية
            Positioned.fill(
              child: Image.asset(
                _getSelectionBackgroundImage(),
                fit: BoxFit.cover,
              ),
            ),
            // طبقة تظليل سوداء خفيفة لتوضيح النصوص والأزرار فوق الصورة
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.settings, color: themeColor, size: 28),
                        onSelected: widget.onThemeChanged,
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(value: 'purple', child: Row(children: [Icon(Icons.palette, color: Colors.deepPurpleAccent), SizedBox(width: 8), Text('الوضع البنفسجي المضيء')])),
                          const PopupMenuItem<String>(value: 'blue', child: Row(children: [Icon(Icons.palette, color: Colors.blueAccent), SizedBox(width: 8), Text('الوضع الأزرق السيان')])),
                          const PopupMenuItem<String>(value: 'dark', child: Row(children: [Icon(Icons.palette, color: Colors.grey), SizedBox(width: 8), Text('الوضع الداكن الكلاسيكي')])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Icon(Icons.language, size: 70, color: themeColor),
                    const SizedBox(height: 12),
                    const Text('بث العالم التفاعلي الشامل', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('استمع وشاهد كل إذاعات وفضائيات العالم بحرية وفك حجب متكامل', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 32),

                    // بطاقة الـ VPN
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _isVpnConnected ? Colors.greenAccent.withOpacity(0.4) : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(_isVpnConnected ? Icons.verified_user : Icons.shield_outlined, size: 40, color: _isVpnConnected ? Colors.greenAccent : Colors.grey),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_isVpnConnected ? 'اتصال الـ VPN نشط للنظام' : 'حماية الشبكة وفك الحجب', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('حالة النظام: $_vpnStatus', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isVpnConnected,
                            activeColor: Colors.greenAccent,
                            onChanged: (value) => _toggleVpn(),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

يُرجى استخدام الرمز البرمجي بحذر.
_buildMenuCard(title: 'راديو العالم الجغرافي', subtitle: 'آلاف المحطات الصوتية الحية المفتوحة', icon: Icons.radio, color: themeColor, onTap: () => _navigateToExplorer(false)),
const SizedBox(height: 16),
_buildMenuCard(title: 'تلفاز العالم الآمن', subtitle: 'قنوات فضائية وإخبارية مجانية غير مشفرة', icon: Icons.live_tv, color: widget.currentTheme == 'dark' ? Colors.redAccent : themeColor, onTap: () => _navigateToExplorer(true)),
],
),
),
),
],
),
),
);
}
Widget _buildMenuCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
return InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(16),
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
child: Row(
children: [
Icon(icon, size: 40, color: color),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
],
),
),
const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30)
],
),
),
);
}
}
// ==========================================
// 2. شاشة مستكشف الخرائط والبحث والمفارقات
// ==========================================
class MainMapExplorerScreen extends StatefulWidget {
final bool isTvMode;
final String currentTheme;
const MainMapExplorerScreen({
super.key,
required this.isTvMode,
required this.currentTheme,
});
@override
State createState() => _MainMapExplorerScreenState();
}
class _MainMapExplorerScreenState extends State {
final MapController _mapController = MapController();
final TextEditingController _searchController = TextEditingController();
final AudioPlayer _audioPlayer = AudioPlayer();
VideoPlayerController? _videoPlayerController;
BannerAd? _bannerAd;
bool _isBannerLoaded = false;
List _items = [];
List _countries = [];
List _favoriteIds = [];
bool _isLoading = true;
String _selectedCountryCode = 'US';
Map<String, dynamic>? _currentItem;
bool _isPlaying = false;
@override
void initState() {
super.initState();
_loadFavorites();
_fetchCountries();
_fetchData(_selectedCountryCode);
_initBannerAd();
_audioPlayer.playingStream.listen((playing) {
if (!widget.isTvMode && mounted) setState(() => _isPlaying = playing);
});
}
@override
void dispose() {
_audioPlayer.dispose();
_videoPlayerController?.dispose();
_searchController.dispose();
_bannerAd?.dispose();
super.dispose();
}
void _initBannerAd() {
_bannerAd = BannerAd(
adUnitId: 'ca-app-pub-3940256099942544/6300978111',
size: AdSize.banner,
request: const AdRequest(),
listener: BannerAdListener(
onAdLoaded: (ad) => setState(() => _isBannerLoaded = true),
onAdFailedToLoad: (ad, error) => ad.dispose(),
),
);
_bannerAd!.load();
}
// ربط خريطة الخلفية بالثيمات والصور المخصصة
String _getMapUrlTemplate() {
if (widget.currentTheme == 'blue') {
return 'https://{s}{z}/{x}/{y}{r}.png'; // النطاق النهاري الأزرق الملاحي
}
if (widget.currentTheme == 'dark') {
return 'https://{s}{z}/{x}/{y}{r}.png'; // النطاق الأسود الكامل بدون علامات مشتتة
}
return 'https://{s}{z}/{x}/{y}{r}.png'; // النطاق الليلي البنفسجي الافتراضي
}
Future _fetchCountries() async {
try {
final response = await http.get(Uri.parse('radio-browser.info'));
if (response.statusCode == 200) {
setState(() {
_countries = json.decode(response.body);
_countries.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
});
}
} catch (e) {
debugPrint("خطأ في جلب الدول: $e");
}
}
Future _fetchData(String countryCode) async {
setState(() => _isLoading = true);
try {
if (widget.isTvMode) {
final response = await http.get(Uri.parse('github.io'));
if (response.statusCode == 200) {
List allTvChannels = json.decode(response.body);
setState(() {
_items = allTvChannels.where((channel) {
bool matchesCountry = false;
if (channel['countries'] != null) {
for (var c in channel['countries']) {
if (c['code'].toString().toLowerCase() == countryCode.toLowerCase()) {
matchesCountry = true;
break;
}
}
}
return matchesCountry && channel['url'] != null && channel['url'].toString().isNotEmpty;
}).toList();
_isLoading = false;
});
if (_items.isNotEmpty) _mapController.move(const LatLng(30.0444, 31.2357), 4.0);
}
} else {
final response = await http.get(Uri.parse('radio-browser.info'));
if (response.statusCode == 200) {
List rawData = json.decode(response.body);
_processRadioItems(rawData);
}
}
} catch (e) {
setState(() => _isLoading = false);
}
}
Future _searchItems(String query) async {
if (query.trim().isEmpty) return;
setState(() => _isLoading = true);
try {
if (widget.isTvMode) {
final response = await http.get(Uri.parse('github.io'));
if (response.statusCode == 200) {
List allChannels = json.decode(response.body);
setState(() {
_items = allChannels.where((c) => c['name'].toString().toLowerCase().contains(query.toLowerCase()) && c['url'] != null).toList();
_isLoading = false;
});
}
} else {
final response = await http.get(Uri.parse('radio-browser.info{Uri.encodeComponent(query)}'));
if (response.statusCode == 200) {
List results = json.decode(response.body);
_processRadioItems(results);
}
}
} catch (e) {
setState(() => _isLoading = false);
}
}
void _processRadioItems(List rawData) {
setState(() {
_items = rawData.where((element) => element['geo_lat'] != null && element['geo_long'] != null && element['url_resolved'] != null).toList();
_isLoading = false;
});
if (_items.isNotEmpty) {
_mapController.move(LatLng(double.parse(_items['geo_lat'].toString()), double.parse(_items['geo_long'].toString())), 5.0);
}
}
String get _favKey => widget.isTvMode ? 'fav_tv_ids' : 'fav_radio_ids';
Future _loadFavorites() async {
final prefs = await SharedPreferences.getInstance();
setState(() => _favoriteIds = prefs.getStringList(_favKey) ?? []);
}
Future _toggleFavorite(String id) async {
final prefs = await SharedPreferences.getInstance();
setState(() {
if (_favoriteIds.contains(id)) {
_favoriteIds.remove(id);
} else {
_favoriteIds.add(id);
}
});
await prefs.setStringList(_favKey, _favoriteIds);
}
Future _startStreaming(Map<String, dynamic> item) async {
setState(() {
_currentItem = item;
_isPlaying = false;
});
await _audioPlayer.stop();
if (_videoPlayerController != null) {
await _videoPlayerController!.dispose();
_videoPlayerController = null;
}
try {
String streamUrl = widget.isTvMode ? item['url'] : item['url_resolved'];
if (widget.isTvMode) {
videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamUrl))
..initialize().then(() {
setState(() => _isPlaying = true);
_videoPlayerController!.play();
});
} else {
await _audioPlayer.setUrl(streamUrl);
_audioPlayer.play();
}
} catch (e) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('البث المباشر لهذا العنصر غير متاح حالياً.')));
}
}
void _showFavoritesBottomSheet() {
final String idField = widget.isTvMode ? 'id' : 'stationuuid';
final favItems = _items.where((s) => _favoriteIds.contains(s[idField].toString())).toList();
showModalBottomSheet(
context: context,
backgroundColor: const Color(0xFF1E1E1E),
shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
builder: (context) {
return Container(
padding: const EdgeInsets.all(16),
height: 400,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(widget.isTvMode ? 'قنواتي التلفزيونية المفضلة' : 'إذاعاتي المفضلة', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const Divider(color: Colors.white24),
Expanded(
child: favItems.isEmpty
? const Center(child: Text('القائمة فارغة حالياً.', style: TextStyle(color: Colors.grey)))
: ListView.builder(
itemCount: favItems.length,
itemBuilder: (context, index) {
final item = favItems[index];
return ListTile(
leading: Icon(widget.isTvMode ? Icons.tv : Icons.radio, color: widget.isTvMode ? Colors.redAccent : Colors.blueAccent),
title: Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () { _toggleFavorite(item[idField].toString()); Navigator.pop(context); }),
onTap: () {
Navigator.pop(context);
_startStreaming(item);
},
);
},
),
),
],
),
);
},
);
}
@override
Widget build(BuildContext context) {
Color themeColor = widget.currentTheme == 'blue' ? Colors.blueAccent : (widget.currentTheme == 'dark' ? Colors.white70 : Colors.deepPurpleAccent);
final String idField = widget.isTvMode ? 'id' : 'stationuuid';
List markers = [];
if (!widget.isTvMode) {
markers = _items.map((item) {
return Marker(
point: LatLng(double.parse(item['geo_lat'].toString()), double.parse(item['geo_long'].toString())),
width: 40, height: 40,
child: GestureDetector(
onTap: () => _startStreaming(item),
child: Icon(Icons.location_on, size: (_currentItem != null && _currentItem![idField] == item[idField]) ? 38 : 28, color: (_currentItem != null && _currentItem![idField] == item[idField]) ? Colors.greenAccent : themeColor),
),
);
}).toList();
}
return Directionality(
textDirection: TextDirection.rtl,
child: Scaffold(
appBar: AppBar(
title: Text(widget.isTvMode ? 'بث T.V المجاني' : 'خريطة الراديو التفاعلية'),
backgroundColor: Colors.black87,
leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
),
body: Stack(
children: [
FlutterMap(
mapController: _mapController,
options: const MapOptions(initialCenter: LatLng(30.0444, 31.2357), initialZoom: 4.0),
children: [
TileLayer(
urlTemplate: _getMapUrlTemplate(),
subdomains: const ['a', 'b', 'c', 'd'],
),
if (!widget.isTvMode) MarkerLayer(markers: markers),
],
),
if (widget.isTvMode && _items.isNotEmpty)
Positioned.fill(
top: 130,
bottom: _currentItem != null ? 240 : 70,
child: Container(
color: Colors.black71,
child: ListView.builder(
itemCount: _items.length,
itemBuilder: (context, index) {
final channel = _items[index];
return ListTile(
leading: const Icon(Icons.live_tv, color: Colors.redAccent),
title: Text(channel['name'] ?? 'قناة مفتوحة', style: const TextStyle(color: Colors.white)),
subtitle: Text(channel['network'] ?? 'بث مجاني آمن', style: const TextStyle(color: Colors.grey, fontSize: 12)),
onTap: () => _startStreaming(channel),
);
},
),
),
),
Positioned(
top: 16, left: 16, right: 16,
child: Column(
children: [
Container(
padding: const EdgeInsets.symmetric(horizontal: 12),
decoration: BoxDecoration(color: Colors.black97, borderRadius: BorderRadius.circular(12)),
child: TextField(
controller: _searchController,
decoration: InputDecoration(hintText: widget.isTvMode ? 'ابحث عن قناة تلفزيونية...' : 'ابحث عن إذاعة راديو...', border: InputBorder.none, icon: Icon(Icons.search, color: themeColor)),
onSubmitted: (value) => _searchItems(value),
),
),
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 12),
decoration: BoxDecoration(color: Colors.black97, borderRadius: BorderRadius.circular(12)),
child: DropdownButtonHideUnderline(
child: DropdownButton(
value: _selectedCountryCode,
dropdownColor: const Color(0xFF1E1E1E),
items: _countries.map<DropdownMenuItem>((c) => DropdownMenuItem(value: c['iso_3166_1'], child: Text("${c['name']} (${c['stationcount']})"))).toList(),
onChanged: (code) {
if (code != null) {
setState(() => _selectedCountryCode = code);
_fetchData(code);
}
},
),
),
),
),
const SizedBox(width: 8),
FloatingActionButton(mini: true, backgroundColor: Colors.black87, child: const Icon(Icons.favorite, color: Colors.redAccent), onPressed: _showFavoritesBottomSheet)
],
)
],
),
),
if (_isLoading) Center(child: CircularProgressIndicator(color: themeColor)),
if (_currentItem != null)
Positioned(
bottom: _isBannerLoaded ? 70 : 16, left: 16, right: 16,
child: Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
if (widget.isTvMode && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
Container(
height: 160, margin: const EdgeInsets.bottom(10),
decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
child: ClipRRect(
borderRadius: BorderRadius.circular(12),
child: AspectRatio(aspectRatio: _videoPlayerController!.value.aspectRatio, child: VideoPlayer(_videoPlayerController!)),
),
),
Row(
children: [
Expanded(child: Text(_currentItem!['name'] ?? 'بث مباشر', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
IconButton(icon: Icon(_favoriteIds.contains(_currentItem![idField].toString()) ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent), onPressed: () => _toggleFavorite(_currentItem![idField].toString())),
IconButton(
icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, size: 36, color: themeColor),
onPressed: () {
setState(() => _isPlaying = !_isPlaying);
if (widget.isTvMode && _videoPlayerController != null) {
_isPlaying ? _videoPlayerController!.play() : _videoPlayerController!.pause();
} else {
_isPlaying ? _audioPlayer.play() : _audioPlayer.pause();
}
},
),
],
),
],
),
),
),
if (_isBannerLoaded)
Positioned(
bottom: 0, left: 0, right: 0,
child: Container(alignment: Alignment.center, width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), color: Colors.black87, child: AdWidget(ad: _bannerAd!)),
),
],
),
),
);
}
}
