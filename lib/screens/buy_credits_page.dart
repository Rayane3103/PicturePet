import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/credits_service.dart';
import '../theme/app_theme.dart';

class BuyCreditsPage extends StatefulWidget {
  const BuyCreditsPage({super.key});

  @override
  State<BuyCreditsPage> createState() => _BuyCreditsPageState();
}

class _BuyCreditsPageState extends State<BuyCreditsPage> {
  final CreditsService _creditsService = CreditsService.instance;
  late final List<_CreditPackage> _packages = [
    const _CreditPackage(
      id: 'bronze',
      title: 'Bronze',
      credits: 1000,
      priceUsd: 30,
      subtitle: 'Starter',
    ),
    const _CreditPackage(
      id: 'silver',
      title: 'Silver',
      credits: 2000,
      priceUsd: 60,
      subtitle: 'Popular',
      badge: 'Popular',
      highlight: true,
    ),
    const _CreditPackage(
      id: 'gold',
      title: 'Gold',
      credits: 5000,
      priceUsd: 150,
      subtitle: 'Best Value',
    ),
    const _CreditPackage(
      id: 'platinum',
      title: 'Platinum',
      credits: 10000,
      priceUsd: 300,
      subtitle: 'Professional',
    ),
  ];

  late _CreditPackage _selectedPackage = _packages[1];
  bool _isProcessing = false;
  String? _error;

  Future<void> _handlePurchase() async {
    setState(() {
      _error = null;
      _isProcessing = true;
    });

    try {
      final success = await _creditsService.purchaseCredits(
        amount: _selectedPackage.credits,
        description:
            '${_selectedPackage.title} pack (${_selectedPackage.credits} credits)',
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Added ${_selectedPackage.credits} credits to your balance.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'Something went wrong. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onBg = AppColors.onBackground(context);
    final secondary = AppColors.secondaryText(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Credits'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.card(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.muted(context).withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Buy Credits',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: onBg,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Purchase credits in packages of 1,000 credits for \$30 each.',
                                  style: GoogleFonts.inter(
                                    color: secondary,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Quick Selection',
                                  style: GoogleFonts.inter(
                                    color: AppColors.secondaryText(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _packages.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.55,
                                  ),
                                  itemBuilder: (context, index) {
                                    final pkg = _packages[index];
                                    return _CreditPackageCard(
                                      package: pkg,
                                      selected: pkg.id == _selectedPackage.id,
                                      onTap: () {
                                        setState(() => _selectedPackage = pkg);
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                _CheckoutSummary(
                                  selected: _selectedPackage,
                                ),
                                const SizedBox(height: 12),
                                if (_error != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _error!,
                                      style: GoogleFonts.inter(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: secondary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Secure payment via Stripe',
                                style: GoogleFonts.inter(
                                  color: secondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: _CheckoutButton(
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : _handlePurchase,
          ),
        ),
      ),
    );
  }
}

class _CreditPackage {
  final String id;
  final String title;
  final String subtitle;
  final int credits;
  final int priceUsd;
  final String? badge;
  final bool highlight;

  const _CreditPackage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.credits,
    required this.priceUsd,
    this.badge,
    this.highlight = false,
  });

  String get priceLabel => '\$$priceUsd';
  String get formattedCredits => credits
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[0]},');
}

class _CreditPackageCard extends StatelessWidget {
  const _CreditPackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final _CreditPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.primaryPurple
        : AppColors.muted(context).withOpacity(0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryPurple.withOpacity(0.05)
                    : AppColors.card(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 1.6 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryPurple.withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${package.formattedCredits} credits',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBackground(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    package.priceLabel,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBackground(context),
                    ),
                  ),
                  Text(
                    package.subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (package.badge != null)
              Positioned(
                top: -10,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: package.highlight
                        ? AppColors.primaryPurple
                        : AppColors.muted(context),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    package.badge!,
                    style: GoogleFonts.inter(
                      color: package.highlight
                          ? Colors.white
                          : AppColors.onBackground(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({required this.selected});

  final _CreditPackage selected;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.muted(context).withOpacity(0.25);
    final secondary = AppColors.secondaryText(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        color: AppColors.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total',
            style: GoogleFonts.inter(
              color: secondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${selected.formattedCredits} credits',
                  style: GoogleFonts.inter(
                    color: AppColors.onBackground(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                selected.priceLabel,
                style: GoogleFonts.inter(
                  color: AppColors.onBackground(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.6 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: disabled ? null : onPressed,
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 3,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Image.asset('assets/images/logo.png'),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Continue to Checkout',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

