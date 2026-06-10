import 'package:flutter/material.dart';
import 'screens/account/login_screen.dart';
import 'screens/account/register_screen.dart';

// ── Neofyn Bharath Brand Colors ──────────────────────────────────────────────
class NeofynColors {
  static const background     = Color(0xFF2A1A0E); // deep coffee brown
  static const surface        = Color(0xFF1A0D06); // bottom sheet / matte
  static const card           = Color(0xFF3D2010); // slide illustration bg
  static const cardAlt        = Color(0xFF2B1A0F); // alternate illustration bg
  static const cardDark       = Color(0xFF1E1208); // darker illustration bg
  static const primary        = Color(0xFFC8956C); // warm amber-brown accent
  static const primaryDark    = Color(0xFF5C3A21); // N-icon background
  static const textPrimary    = Colors.white;
  static const textSecondary  = Color(0xFF8A7060); // muted warm grey
  static const textHint       = Color(0xFF5A4030);
  static const divider        = Color(0x14FFFFFF);
  static const chipBg         = Color(0x26C8956C);
  static const chipBorder     = Color(0x4DC8956C);
  static const dotInactive    = Color(0x40C8956C);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'tag':   'Transfer',
      'title': 'Easy Money\nTransfer',
      'desc':  'Send money instantly to any bank or UPI ID with zero hidden fees.',
      'icon':  Icons.send_rounded,
      'chipL': '⚡ Instant',
      'chipR': '₹0 Fees',
      'bg':    NeofynColors.card,
    },
    {
      'tag':   'Withdrawal',
      'title': 'Cashless\nWithdrawals',
      'desc':  'Withdraw cash from any partner ATM or merchant without a card.',
      'icon':  Icons.credit_card_off_outlined,
      'chipL': '📍 Nearby',
      'chipR': 'Card-free',
      'bg':    NeofynColors.cardAlt,
    },
    {
      'tag':   'Recharge',
      'title': 'Hassle-free\nRecharges',
      'desc':  'Fast fingerprint & one-click recharges for mobile, DTH, and data cards.',
      'icon':  Icons.fingerprint_rounded,
      'chipL': '⚡ One-tap',
      'chipR': 'Instant',
      'bg':    NeofynColors.cardDark,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeofynColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NeofynLogo(),
                  TextButton(
                    onPressed: () => _navigateToLogin(),
                    child: const Text(
                      'Skip →',
                      style: TextStyle(
                        color: Color(0x80FFFFFF),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Slides ────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildSlide(_pages[i]),
              ),
            ),

            // ── Bottom Buttons (No dark box) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => _buildDot(i),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Log in
                  _PrimaryButton(
                    label: 'Log in',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sign up
                  _OutlineButton(
                    label: 'Sign up',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RegisterScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Security badge
                  Row(
                    children: const [
                      Expanded(child: Divider(color: NeofynColors.divider)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '🔒 Secured by 256-bit encryption',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0x4DFFFFFF),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: NeofynColors.divider)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Slide ──────────────────────────────────────────────────────────────────
  Widget _buildSlide(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration card
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: data['bg'] as Color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NeofynColors.primary.withOpacity(0.15),
                      width: 2,
                    ),
                  ),
                ),
                // Inner ring
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NeofynColors.primary.withOpacity(0.30),
                      width: 1.5,
                    ),
                  ),
                ),
                // Icon tile
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: NeofynColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    data['icon'] as IconData,
                    size: 30,
                    color: NeofynColors.surface,
                  ),
                ),
                // Top-left chip
                Positioned(
                  top: 16,
                  left: 16,
                  child: _Chip(data['chipL'] as String),
                ),
                // Bottom-right chip
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _Chip(data['chipR'] as String),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tag
          Text(
            (data['tag'] as String).toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: NeofynColors.primary,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            data['title'] as String,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: NeofynColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            data['desc'] as String,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0x8CFFFFFF),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Dot indicator ──────────────────────────────────────────────────────────
  Widget _buildDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 6),
      height: 6,
      width: isActive ? 22 : 6,
      decoration: BoxDecoration(
        color: isActive ? NeofynColors.primary : NeofynColors.dotInactive,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  void _navigateToLogin() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => LoginScreen()),
  );
}

// ── Logo Widget ────────────────────────────────────────────────────────────
// ── Logo Widget (using asset image with correct sizing) ───────────────────
class _NeofynLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Use a constrained container to prevent overflow
    return SizedBox(
      height: 180,                  // fixed height – adjust as needed
      child: Image.asset(
        'assets/images/logo_white.png',
        fit: BoxFit.contain,      // keeps aspect ratio, no distortion
      ),
    );
  }
}

// ── Chip Widget ────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: NeofynColors.chipBg,
        border: Border.all(color: NeofynColors.chipBorder, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: NeofynColors.primary,
        ),
      ),
    );
  }
}

// ── Primary Button ─────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: NeofynColors.primary,
          foregroundColor: NeofynColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Outline Button ─────────────────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x33FFFFFF), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}