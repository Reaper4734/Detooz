import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/ui/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Import all screens
import 'package:app/ui/screens/login_screen.dart';
import 'package:app/ui/screens/dashboard_screen.dart';
import 'package:app/ui/screens/education_screen.dart';
import 'package:app/ui/screens/edit_profile_screen.dart';
import 'package:app/ui/screens/settings_screen.dart';
import 'package:app/ui/screens/article_webview.dart';
import 'package:app/ui/screens/bookmarks_screen.dart';
import 'package:app/ui/screens/feed_screen.dart';
import 'package:app/ui/screens/guardians_screen.dart';
import 'package:app/ui/screens/history_screen.dart';
import 'package:app/ui/screens/language_selector_screen.dart';
import 'package:app/ui/screens/otp_verification_screen.dart';
import 'package:app/ui/screens/permission_wizard_screen.dart';
import 'package:app/ui/screens/privacy_security_screen.dart';
import 'package:app/ui/screens/scan_detail_screen.dart';

// Import Contracts
import 'package:app/contracts/risk_level.dart';
import 'package:app/contracts/scan_view_model.dart';
import 'package:app/contracts/article.dart';
import 'package:app/contracts/guardian_view_model.dart';

// Import Providers
import 'package:app/ui/providers.dart';
import 'package:app/ui/providers/education_provider.dart';

void main() {
  runApp(const PreviewApp());
}

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        // --- PROPER NOTIFIER OVERRIDES ---
        authProvider.overrideWith((ref) => MockAuthNotifier(ref)),
        userProfileProvider.overrideWith((ref) => MockUserProfileNotifier()),
        scansProvider.overrideWith((ref) => MockScansNotifier(ref)),
        
        // Explicitly override scanHistoryProvider to ensure it has data
        scanHistoryProvider.overrideWith((ref) => _mockScans),
        
        guardiansProvider.overrideWith((ref) => MockGuardiansNotifier(ref)),
        userStatsProvider.overrideWith((ref) => MockUserStatsNotifier()),
        userSettingsProvider.overrideWith((ref) => MockUserSettingsNotifier()),
        trustedSendersProvider.overrideWith((ref) => MockTrustedSendersNotifier()),
        
        // Education Overrides
        // 1. Override for infinite scroll feeds
        feedProvider('all').overrideWith((ref) => MockFeedNotifier('all', _mockArticles)),
        feedProvider('news').overrideWith((ref) => MockFeedNotifier('news', _mockArticles)),
        feedProvider('alert').overrideWith((ref) => MockFeedNotifier('alert', _mockArticles)),
        feedProvider('tip').overrideWith((ref) => MockFeedNotifier('tip', _mockArticles)),
        
        // 2. Override for education dashboard ("educationFeedProvider")
        // 2. Override for education dashboard ("educationFeedProvider")
        // FutureProvider override expects a FutureOr<T>, NOT an AsyncValue
        educationFeedProvider('all').overrideWith((ref) => FeedResponse(
             articles: _mockArticles,
             total: _mockArticles.length,
             exclusive: [],
        )),
        educationFeedProvider('alert').overrideWith((ref) => FeedResponse(
             articles: [], 
             total: 0, 
             exclusive: []
        )),
        educationFeedProvider('tip').overrideWith((ref) => FeedResponse(
             articles: [], 
             total: 0, 
             exclusive: []
        )),
        educationFeedProvider('news').overrideWith((ref) => FeedResponse(
             articles: [], 
             total: 0, 
             exclusive: []
        )),
        
        bookmarksNotifierProvider.overrideWith((ref) => MockBookmarksNotifier()),

        // Language Override
        languageProvider.overrideWith((ref) => MockLanguageNotifier()),
      ],
      child: MaterialApp(
        title: 'Detooz UI Preview',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.backgroundDark,
          primaryColor: AppColors.primary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.success,
            surface: AppColors.surfaceDark,
            error: AppColors.danger,
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          useMaterial3: true,
        ),
        home: const GalleryScreen(),
      ),
    );
  }
}

// --- MOCK NOTIFIERS ---

class MockLanguageNotifier extends LanguageNotifier {
  MockLanguageNotifier() : super() {
    state = 'en';
  }
  
  @override
  Future<void> _initLanguage() async {
    // No-op
  }
  
  @override
  Future<void> setLanguage(String code) async {
    state = code;
  }
}

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier(Ref ref) : super(ref) {
    state = const AsyncValue.data(true);
  }

  @override
  Future<void> checkAuth() async {
    // No-op
  }
}

class MockUserProfileNotifier extends UserProfileNotifier {
  MockUserProfileNotifier() : super() {
    state = AsyncValue.data(UserProfile(
      id: 123, 
      email: 'preview@detooz.com',
      firstName: 'Preview',
      lastName: 'User',
      phone: '+1234567890',
      emailVerified: true,
      phoneVerified: true,
    ));
  }

  @override
  Future<void> loadProfile() async {
    // No-op
  }
}

class MockScansNotifier extends ScansNotifier {
  MockScansNotifier(Ref ref) : super(ref) {
    state = AsyncValue.data(_mockScans);
  }

  @override
  Future<void> loadScans() async {
    // No-op
  }
}

class MockGuardiansNotifier extends GuardiansNotifier {
  MockGuardiansNotifier(Ref ref) : super(ref) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> loadGuardians() async {
    // No-op
  }
}

class MockUserStatsNotifier extends UserStatsNotifier {
  MockUserStatsNotifier() : super() {
    state = AsyncValue.data(UserStats(
      totalScans: 125,
      highRiskBlocked: 5,
      mediumRiskDetected: 12,
      lowRiskSafe: 108,
      guardiansCount: 2,
      trustedSendersCount: 5,
      blockedSendersCount: 3,
      protectionScore: 85,
      lastScanAt: DateTime.now(),
    ));
  }

  @override
  Future<void> loadStats() async {
    // No-op
  }
}

class MockUserSettingsNotifier extends UserSettingsNotifier {
  MockUserSettingsNotifier() : super() {
    state = AsyncValue.data(UserSettings(
      language: 'en',
      autoBlockHighRisk: true,
      alertGuardiansThreshold: 'HIGH',
      receiveTips: true,
    ));
  }

  @override
  Future<void> loadSettings() async {
    // No-op
  }
}

class MockTrustedSendersNotifier extends TrustedSendersNotifier {
  MockTrustedSendersNotifier() : super() {
    state = const AsyncValue.data([]); 
  }
  
  @override
  Future<void> loadTrustedSenders() async {
    // No-op
  }
}

class MockFeedNotifier extends FeedNotifier {
  final List<Article> mockData;
  MockFeedNotifier(String category, this.mockData) : super(category) {
    state = FeedState(
      articles: mockData,
      isLoading: false,
      hasMore: false,
      offset: 0,
    );
  }
  
  @override
  Future<void> loadMore() async {} 
}

class MockBookmarksNotifier extends BookmarksNotifier {
  MockBookmarksNotifier() : super() {
    state = AsyncValue.data(_mockArticles.take(1).toList());
  }
  @override Future<void> loadBookmarks() async {}
}

// --- GALLERY SCREEN ---

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Dashboard',
    'Education',
    'Feed (All)',
    'Scan History',
    'Guardians',
    'Edit Profile',
    'Settings',
    'Permissions',
    'Language',
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      const EducationScreen(),
      const FeedScreen(category: 'all'),
      const HistoryScreen(), // Should work with scanHistoryProvider override
      const GuardiansScreen(),
      const EditProfileScreen(),
      const SettingsScreen(),
      const PermissionWizardScreen(),
      _buildLanguageSelectorLauncher(),
    ];
  }

  Widget _buildLanguageSelectorLauncher() {
    return Consumer(
      builder: (context, ref, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Language Selector Test')),
          body: Center(
            child: ElevatedButton(
              onPressed: () => showLanguageSelector(context, ref),
              child: const Text('Open Language Selector'),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showScreenSelector,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.layers, color: Colors.white),
      ),
    );
  }

  void _showScreenSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      builder: (context) {
        return ListView.builder(
          itemCount: _titles.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(_titles[index], style: const TextStyle(color: Colors.white)),
              selected: _currentIndex == index,
              selectedColor: Theme.of(context).primaryColor,
              onTap: () {
                setState(() => _currentIndex = index);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}

// --- MOCK DATA ---

final _mockScan = ScanViewModel(
  id: 'scan_123',
  senderNumber: '+1234567890',
  message: 'Win a free iPhone now! Click http://scam.com',
  messagePreview: 'Win a free iPhone now! Click...',
  riskLevel: RiskLevel.high,
  source: 'local',
  platform: PlatformType.sms,
  scannedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  riskReason: 'Phishing link detected',
  confidence: 0.95,
);

final List<ScanViewModel> _mockScans = [
  _mockScan,
  ScanViewModel(
    id: 'scan_124',
    senderNumber: 'Mom',
    message: 'Call me when you are home.',
    messagePreview: 'Call me when you are home.',
    riskLevel: RiskLevel.low,
    source: 'cloud',
    platform: PlatformType.whatsapp,
    scannedAt: DateTime.now().subtract(const Duration(hours: 2)),
    confidence: 0.1,
  ),
  ScanViewModel(
    id: 'scan_125',
    senderNumber: 'Unknown',
    message: 'Urgent: Wire money to...',
    messagePreview: 'Urgent: Wire money to...',
    riskLevel: RiskLevel.medium,
    source: 'cloud',
    platform: PlatformType.telegram,
    scannedAt: DateTime.now().subtract(const Duration(days: 1)),
    riskReason: 'Suspicious financial request',
    confidence: 0.65,
  ),
];

final List<Article> _mockArticles = [
  Article(
      url: 'https://example.com/1',
      title: 'How to Spot a Phishing Scam',
      summary: 'Learn the red flags of common phishing attempts in emails and SMS.',
      source: 'CyberSafe',
      category: 'tip',
      readTimeMins: 5,
      imageUrl: 'https://picsum.photos/400/200',
      publishedAt: DateTime.now()
  ),
  Article(
      url: 'https://example.com/2',
      title: 'New WhatsApp Scam Alert',
      summary: 'A new verification code scam is targeting users via WhatsApp.',
      source: 'TechNews',
      category: 'alert',
      readTimeMins: 2,
      imageUrl: 'https://picsum.photos/400/201',
      publishedAt: DateTime.now()
  ),
];
