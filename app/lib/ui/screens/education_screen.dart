import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers.dart';

class EducationScreen extends ConsumerStatefulWidget {
  const EducationScreen({super.key});

  @override
  ConsumerState<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends ConsumerState<EducationScreen> {
  // Category state
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'New Scams', 'Basics', 'Safety Tips', 'Deepfakes'];

  // Search controller
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark, // True Black
      body: SafeArea(
        bottom: false, // Allow content to flow behind navbar if needed, but safe top
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100), // Space for bottom nav
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // 1️⃣ Header & Search
              _buildHeader(),
              const SizedBox(height: 16),
              
              // 2️⃣ Category Chips
              _buildCategoryChips(),
              const SizedBox(height: 24),
              
              // 3️⃣ Featured Alert Card
              _buildFeaturedAlert(),
              const SizedBox(height: 32),
              
              // 4️⃣ Scam Dictionary
              _buildScamDictionary(),
              const SizedBox(height: 32),
              
              // 5️⃣ Golden Rules
              _buildGoldenRules(),
              const SizedBox(height: 32),
              
              // 6️⃣ Quick Check
              _buildQuickCheck(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- Sections ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr(
            'Learn to Protect Yourself',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          // Search Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(50), // Pill shape
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B).withOpacity(0.75), // Zinc Glass
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF9CA3AF)), // Neutral-400
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: tr('Search scams, tips...'),
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : const Color(0xFF18181B).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Tr(
                  category,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : const Color(0xFFE5E7EB), // Neutral-200
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeaturedAlert() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Gradient border simulator using container nesting or simplifed border
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          // We can't do the complex overflow glow easily without stack, 
          // keeping it simple for stability but matching style
          color: const Color(0xFF18181B).withOpacity(0.75), // Zinc Glass
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Image Area
              Container(
                height: 160,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuA4OCeQQyXqAm20KpXhKgXPXFO-F9MEGC4EVcvaniXOnk_92IokpqaqqZheNB_K2kbQBOPqceip80z608dJha8foy21kZQjZzu4ZKgSdA8WZdmKZnba2iHkN0DqYvf8y8aw6HhaNVkojV-9J_s7bnLpWs6hewW48z87rk-VKs5fw2J2qGFqf7aU8RMZ44zWEfPfr62zdw1YxQvrsT374sUwrur96L7c5rIZSrY-sJX5Em5GU3YQce8KB75uf1hy1eFJxE0iR_vG3aM'), 
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: AppColors.primary.withOpacity(0.9),
                            child: Tr(
                              'ALERT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content Area
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tr(
                      'AI Voice Cloning Scams',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Tr(
                      'Criminals are using AI to mimic voices of loved ones. Learn the 3 signs to spot a fake call instantly.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD4D4D8), // Neutral-300
                        fontSize: 14,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Tr(
                              'Read Full Alert',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                          ],
                        ),
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

  Widget _buildScamDictionary() {
    final scams = [
      {'icon': Icons.phishing, 'color': Colors.blue, 'title': 'Phishing', 'desc': 'Email & SMS tricks'},
      {'icon': Icons.favorite, 'color': Colors.pink, 'title': 'Romance', 'desc': 'Fake relationships'},
      {'icon': Icons.support_agent, 'color': Colors.orange, 'title': 'Tech Support', 'desc': 'Fake virus alerts'},
      {'icon': Icons.currency_bitcoin, 'color': Colors.yellow, 'title': 'Crypto', 'desc': 'Investment fraud'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Tr(
                'Scam Dictionary',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Tr(
                'See all',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: scams.length,
            itemBuilder: (context, index) {
              final scam = scams[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B).withOpacity(0.75), // Zinc Glass
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (scam['color'] as Color).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(scam['icon'] as IconData, color: (scam['color'] as Color).withOpacity(0.8), size: 20),
                    ),
                    const SizedBox(height: 12),
                    Tr(
                      scam['title'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Tr(
                      scam['desc'] as String,
                      style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoldenRules() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr(
            'Golden Rules',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF18181B).withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                _buildRuleItem(
                  Icons.shield,
                  'Never share OTPs',
                  'Banks will never ask for your One-Time Password over the phone.',
                ),
                Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                _buildRuleItem(
                  Icons.link_off,
                  'Verify before clicking',
                  "Check the sender's email address carefully for misspellings.",
                ),
                Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Tr(
                          'View all 10 Golden Rules',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.green.shade400, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tr(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Tr(
                  desc,
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCheck() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr(
            'Quick Check: Bank Calls',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B).withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Flex(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Tr(
                            'DO',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Tr(
                        'Hang up and call the number on the back of your card.',
                        style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 80, color: Colors.white.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 16)),
                // DON'T
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cancel, color: Colors.red, size: 18),
                          const SizedBox(width: 6),
                          Tr(
                            'DON\'T', // Escaped single quote
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Tr(
                        'Trust the caller ID or press numbers to "speak to an agent".',
                        style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
