import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/formatting/app_format.dart';
import '../../core/models/models.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';

const _goodTraitKeys = [
  'trait_good_punctual',
  'trait_good_polite',
  'trait_good_clear_communication',
  'trait_good_pickup_ready',
  'trait_good_cooperative',
];

const _badTraitKeys = [
  'trait_bad_late',
  'trait_bad_rude',
  'trait_bad_wrong_pin',
  'trait_bad_no_show',
  'trait_bad_payment_delay',
];

class RateClientScreen extends ConsumerStatefulWidget {
  const RateClientScreen({super.key});

  @override
  ConsumerState<RateClientScreen> createState() => _RateClientScreenState();
}

class _RateClientScreenState extends ConsumerState<RateClientScreen> {
  int _stars = 0;
  final _comment = TextEditingController();
  final Set<String> _goodSelected = {};
  final Set<String> _badSelected = {};
  bool _submitting = false;
  bool _submitted = false;
  int _activeCategoryIndex = 0; // 0: What went well, 1: Could improve

  bool get _canSubmit => _stars >= 1 && !_submitting;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final ok = await ref
        .read(driverAppStateProvider.notifier)
        .submitClientRating(
          rating: _stars,
          comment: _comment.text.trim(),
          goodTraits: _goodSelected.map((k) => k.tr()).toList(),
          badTraits: _badSelected.map((k) => k.tr()).toList(),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) _submitted = true;
    });
    if (ok) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _finish();
        }
      });
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('rating_submit_failed'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await ref
        .read(driverAppStateProvider.notifier)
        .completeClientRatingSession();
    if (!mounted) return;
    context.go('/home');
  }

  String _getStarLabel(int stars) {
    switch (stars) {
      case 1:
        return '😠 ${'rating_poor'.tr()}';
      case 2:
        return '😐 ${'rating_fair'.tr()}';
      case 3:
        return '🙂 ${'rating_good'.tr()}';
      case 4:
        return '😊 ${'rating_very_good'.tr()}';
      case 5:
        return '🤩 ${'rating_excellent'.tr()}';
      default:
        return 'rating_select_stars'.tr();
    }
  }

  IconData _getTraitIcon(String key) {
    switch (key) {
      case 'trait_good_punctual':
        return Icons.timer_rounded;
      case 'trait_good_polite':
        return Icons.sentiment_very_satisfied_rounded;
      case 'trait_good_clear_communication':
        return Icons.chat_bubble_rounded;
      case 'trait_good_pickup_ready':
        return Icons.location_on_rounded;
      case 'trait_good_cooperative':
        return Icons.handshake_rounded;
      case 'trait_bad_late':
        return Icons.watch_later_rounded;
      case 'trait_bad_rude':
        return Icons.sentiment_very_dissatisfied_rounded;
      case 'trait_bad_wrong_pin':
        return Icons.wrong_location_rounded;
      case 'trait_bad_no_show':
        return Icons.person_off_rounded;
      case 'trait_bad_payment_delay':
        return Icons.price_check_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverAppStateProvider);
    final request = state.currentRequest;
    final fare = request?.fare ?? 0;
    final fareStr = formatTripPrice(fare);
    final clientName =
        (request?.clientName != null && request!.clientName.trim().isNotEmpty)
        ? request.clientName
        : 'client_label'.tr();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            _submitted ? "app_title".tr() : 'rate_client'.tr(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _submitted
                ? _buildSuccessView(state, request, fare, fareStr)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Modern Client Summary Hero Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.brandOrange.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.brandOrange.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.brandOrange,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clientName,
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'order_completed'.tr(),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (fare > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.brandOrange.withValues(
                                        alpha: 0.15,
                                      ),
                                      AppColors.brandOrange.withValues(
                                        alpha: 0.08,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.brandOrange.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  fareStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppColors.brandOrange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Security Notice Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.brandOrange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 22,
                              color: AppColors.brandOrange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'rating_required_notice'.tr(),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Interactive Star Rating Section Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'rating_how_was_client'.tr(),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final n = index + 1;
                                final filled = n <= _stars;
                                return InkWell(
                                  onTap: () => setState(() => _stars = n),
                                  borderRadius: BorderRadius.circular(30),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: AnimatedScale(
                                      scale: filled ? 1.18 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: Icon(
                                        filled
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 44,
                                        color: filled
                                            ? AppColors.brandOrange
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 10),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                key: ValueKey(_stars),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _stars == 0
                                      ? Colors.grey.shade100
                                      : AppColors.brandOrange.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getStarLabel(_stars),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _stars == 0
                                        ? Colors.grey.shade600
                                        : AppColors.brandOrange,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Modern Segmented Category Selector Pill
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _activeCategoryIndex = 0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _activeCategoryIndex == 0
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _activeCategoryIndex == 0
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.06,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.thumb_up_rounded,
                                        size: 16,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'rating_good_traits'.tr(),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: _activeCategoryIndex == 0
                                              ? AppColors.textPrimary
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      if (_goodSelected.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(
                                            color: AppColors.brandOrange,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${_goodSelected.length}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _activeCategoryIndex = 1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _activeCategoryIndex == 1
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _activeCategoryIndex == 1
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.06,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.info_rounded,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'rating_bad_traits'.tr(),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: _activeCategoryIndex == 1
                                              ? AppColors.textPrimary
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      if (_badSelected.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade600,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${_badSelected.length}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category Trait Cards
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _activeCategoryIndex == 0
                            ? GridView.builder(
                                key: const ValueKey('good_traits_grid'),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 2.5,
                                    ),
                                itemCount: _goodTraitKeys.length,
                                itemBuilder: (context, index) {
                                  final key = _goodTraitKeys[index];
                                  final isChecked = _goodSelected.contains(key);
                                  return _buildModernCheckboxTile(
                                    key: key,
                                    label: key.tr(),
                                    isChecked: isChecked,
                                    activeColor: AppColors.brandOrange,
                                    icon: _getTraitIcon(key),
                                    onTap: () {
                                      setState(() {
                                        if (isChecked) {
                                          _goodSelected.remove(key);
                                        } else {
                                          _goodSelected.add(key);
                                        }
                                      });
                                    },
                                  );
                                },
                              )
                            : GridView.builder(
                                key: const ValueKey('bad_traits_grid'),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 2.5,
                                    ),
                                itemCount: _badTraitKeys.length,
                                itemBuilder: (context, index) {
                                  final key = _badTraitKeys[index];
                                  final isChecked = _badSelected.contains(key);
                                  return _buildModernCheckboxTile(
                                    key: key,
                                    label: key.tr(),
                                    isChecked: isChecked,
                                    activeColor: Colors.red.shade600,
                                    icon: _getTraitIcon(key),
                                    onTap: () {
                                      setState(() {
                                        if (isChecked) {
                                          _badSelected.remove(key);
                                        } else {
                                          _badSelected.add(key);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Driver Comments Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: AppColors.brandOrange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'optional_comment'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _comment,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'rating_comment_hint'.tr(),
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13.5,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandOrange,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Gradient Primary Action Button
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: _canSubmit
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.brandOrange,
                                    Color(0xFFE65100),
                                  ],
                                )
                              : null,
                          boxShadow: _canSubmit
                              ? [
                                  BoxShadow(
                                    color: AppColors.brandOrange.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [],
                        ),
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: AppColors.brandOrange
                                .withValues(alpha: 0.35),
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _stars == 0
                                          ? 'rating_stars_required'.tr()
                                          : 'submit'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    if (_stars > 0) ...[
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.send_rounded,
                                        size: 19,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernCheckboxTile({
    required String key,
    required String label,
    required bool isChecked,
    required Color activeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isChecked ? activeColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isChecked ? activeColor : Colors.grey.shade200,
          width: isChecked ? 2.0 : 1.0,
        ),
        boxShadow: isChecked
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Trait Icon Badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? activeColor
                        : activeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: isChecked ? Colors.white : activeColor,
                  ),
                ),
                const SizedBox(width: 8),

                // Trait Title Text
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                      color: isChecked
                          ? AppColors.textPrimary
                          : Colors.grey.shade700,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Custom Checkbox Circular Indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isChecked ? activeColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isChecked ? activeColor : Colors.grey.shade400,
                      width: 1.8,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(
    DriverAppState state,
    TripRequest? request,
    double fare,
    String fareStr,
  ) {
    // final clientName =
    //     (request?.clientName != null && request!.clientName.trim().isNotEmpty)
    //     ? request.clientName
    //     : 'client_label'.tr();
    // final clientPhone = request?.clientPhone ?? '';
    // final ratingVal = request?.clientRating ?? 5.0;
    // final timerDisplay = state.tripStartedAt != null
    //     ? _formatTimer(state.tripStartedAt)
    //     : '${request?.estimatedDurationMinutes ?? 15} min';
    // final distanceKmStr = request != null
    //     ? '${request.distanceKm.toStringAsFixed(1)} km'
    //     : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 56,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'rating_submitted_title'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'driver_rating_submitted_message'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        // const SizedBox(height: 24),

        // // ── CLIENT INFO CARD ──
        // Container(
        //   padding: const EdgeInsets.all(16),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(20),
        //     border: Border.all(color: Colors.grey.shade200),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withValues(alpha: 0.04),
        //         blurRadius: 16,
        //         offset: const Offset(0, 4),
        //       ),
        //     ],
        //   ),
        //   child: Row(
        //     children: [
        //       ClipRRect(
        //         borderRadius: BorderRadius.circular(14),
        //         child: Container(
        //           width: 56,
        //           height: 56,
        //           color: AppColors.brandOrange.withValues(alpha: 0.12),
        //           child:
        //               request?.clientAvatar != null &&
        //                   request!.clientAvatar!.trim().isNotEmpty
        //               ? Image.network(
        //                   request.clientAvatar!,
        //                   fit: BoxFit.cover,
        //                   errorBuilder: (_, __, ___) => const Icon(
        //                     Icons.person_rounded,
        //                     size: 32,
        //                     color: AppColors.brandOrange,
        //                   ),
        //                 )
        //               : const Icon(
        //                   Icons.person_rounded,
        //                   size: 32,
        //                   color: AppColors.brandOrange,
        //                 ),
        //         ),
        //       ),
        //       const SizedBox(width: 14),
        //       Expanded(
        //         child: Column(
        //           crossAxisAlignment: CrossAxisAlignment.start,
        //           children: [
        //             Text(
        //               clientName,
        //               maxLines: 1,
        //               overflow: TextOverflow.ellipsis,
        //               style: const TextStyle(
        //                 fontSize: 16,
        //                 fontWeight: FontWeight.bold,
        //                 color: Colors.black,
        //               ),
        //             ),
        //             const SizedBox(height: 4),
        //             Row(
        //               mainAxisSize: MainAxisSize.min,
        //               children: List.generate(5, (index) {
        //                 final starNum = index + 1;
        //                 IconData iconData;
        //                 Color iconColor;
        //                 if (ratingVal >= starNum) {
        //                   iconData = Icons.star_rounded;
        //                   iconColor = const Color(0xFFFFB800);
        //                 } else if (ratingVal >= starNum - 0.5) {
        //                   iconData = Icons.star_half_rounded;
        //                   iconColor = const Color(0xFFFFB800);
        //                 } else {
        //                   iconData = Icons.star_rounded;
        //                   iconColor = Colors.grey.shade300;
        //                 }
        //                 return Icon(iconData, size: 16, color: iconColor);
        //               }),
        //             ),
        //             if (clientPhone.isNotEmpty) ...[
        //               const SizedBox(height: 4),
        //               Text(
        //                 clientPhone,
        //                 style: TextStyle(
        //                   fontSize: 12,
        //                   fontWeight: FontWeight.w500,
        //                   color: Colors.grey.shade600,
        //                 ),
        //               ),
        //             ],
        //           ],
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        // const SizedBox(height: 16),

        // // ── TRIP ROUTE & EARNINGS DETAILS CARD ──
        // Container(
        //   padding: const EdgeInsets.all(16),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(20),
        //     border: Border.all(color: Colors.grey.shade200),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withValues(alpha: 0.04),
        //         blurRadius: 16,
        //         offset: const Offset(0, 4),
        //       ),
        //     ],
        //   ),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.stretch,
        //     children: [
        //       // Fare & Earnings Badge
        //       Container(
        //         padding: const EdgeInsets.symmetric(
        //           horizontal: 16,
        //           vertical: 12,
        //         ),
        //         decoration: BoxDecoration(
        //           color: AppColors.brandOrange.withValues(alpha: 0.08),
        //           borderRadius: BorderRadius.circular(16),
        //           border: Border.all(
        //             color: AppColors.brandOrange.withValues(alpha: 0.2),
        //           ),
        //         ),
        //         child: Row(
        //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //           children: [
        //             Text(
        //               'total_price_label'.tr(),
        //               style: const TextStyle(
        //                 fontSize: 14,
        //                 fontWeight: FontWeight.bold,
        //                 color: Colors.black87,
        //               ),
        //             ),
        //             Text(
        //               fareStr,
        //               style: const TextStyle(
        //                 fontSize: 20,
        //                 fontWeight: FontWeight.w900,
        //                 color: AppColors.brandOrange,
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //       const SizedBox(height: 14),

        //       // Duration & Distance Row
        //       Row(
        //         children: [
        //           const Icon(
        //             Icons.access_time_rounded,
        //             size: 16,
        //             color: Colors.grey,
        //           ),
        //           const SizedBox(width: 6),
        //           Text(
        //             'trip_duration'.tr(),
        //             style: TextStyle(
        //               fontSize: 12.5,
        //               fontWeight: FontWeight.w500,
        //               color: Colors.grey.shade600,
        //             ),
        //           ),
        //           const SizedBox(width: 6),
        //           Text(
        //             timerDisplay,
        //             style: const TextStyle(
        //               fontSize: 13,
        //               fontWeight: FontWeight.bold,
        //               color: Colors.black,
        //             ),
        //           ),
        //           if (distanceKmStr.isNotEmpty) ...[
        //             const Spacer(),
        //             const Icon(
        //               Icons.straighten_rounded,
        //               size: 16,
        //               color: Colors.grey,
        //             ),
        //             const SizedBox(width: 6),
        //             Text(
        //               distanceKmStr,
        //               style: const TextStyle(
        //                 fontSize: 13,
        //                 fontWeight: FontWeight.bold,
        //                 color: Colors.black,
        //               ),
        //             ),
        //           ],
        //         ],
        //       ),
        //       const SizedBox(height: 12),
        //       Divider(color: Colors.grey.shade200, height: 1),
        //       const SizedBox(height: 12),

        //       // Pickup Location
        //       if (request?.pickup != null && request!.pickup.isNotEmpty) ...[
        //         Row(
        //           crossAxisAlignment: CrossAxisAlignment.start,
        //           children: [
        //             Container(
        //               margin: const EdgeInsets.only(top: 4),
        //               width: 10,
        //               height: 10,
        //               decoration: const BoxDecoration(
        //                 color: Colors.blue,
        //                 shape: BoxShape.circle,
        //               ),
        //             ),
        //             const SizedBox(width: 10),
        //             Expanded(
        //               child: Column(
        //                 crossAxisAlignment: CrossAxisAlignment.start,
        //                 children: [
        //                   Text(
        //                     'pickup_point_label'.tr(),
        //                     style: TextStyle(
        //                       fontSize: 12,
        //                       fontWeight: FontWeight.w600,
        //                       color: Colors.grey.shade500,
        //                     ),
        //                   ),
        //                   const SizedBox(height: 2),
        //                   Text(
        //                     request.pickup,
        //                     maxLines: 2,
        //                     overflow: TextOverflow.ellipsis,
        //                     style: const TextStyle(
        //                       fontSize: 13,
        //                       fontWeight: FontWeight.w600,
        //                       color: Colors.black87,
        //                     ),
        //                   ),
        //                 ],
        //               ),
        //             ),
        //           ],
        //         ),
        //         const SizedBox(height: 10),
        //       ],

        //       // Dropoff Location
        //       if (request?.dropOff != null && request!.dropOff.isNotEmpty) ...[
        //         Row(
        //           crossAxisAlignment: CrossAxisAlignment.start,
        //           children: [
        //             Container(
        //               margin: const EdgeInsets.only(top: 4),
        //               width: 10,
        //               height: 10,
        //               decoration: const BoxDecoration(
        //                 color: AppColors.brandOrange,
        //                 shape: BoxShape.circle,
        //               ),
        //             ),
        //             const SizedBox(width: 10),
        //             Expanded(
        //               child: Column(
        //                 crossAxisAlignment: CrossAxisAlignment.start,
        //                 children: [
        //                   Text(
        //                     'dropoff_point_label'.tr(),
        //                     style: TextStyle(
        //                       fontSize: 12,
        //                       fontWeight: FontWeight.w600,
        //                       color: Colors.grey.shade500,
        //                     ),
        //                   ),
        //                   const SizedBox(height: 2),
        //                   Text(
        //                     request.dropOff,
        //                     maxLines: 2,
        //                     overflow: TextOverflow.ellipsis,
        //                     style: const TextStyle(
        //                       fontSize: 13,
        //                       fontWeight: FontWeight.w600,
        //                       color: Colors.black87,
        //                     ),
        //                   ),
        //                 ],
        //               ),
        //             ),
        //           ],
        //         ),
        //       ],
        //     ],
        //   ),
        // ),
        // const SizedBox(height: 28),

        // // ── DONE BUTTON ──
        // PrimaryButton(
        //   label: 'rating_done_button'.tr(),
        //   onPressed: _submitting ? null : _finish,
        //   icon: Icons.done_rounded,
        // ),
        // const SizedBox(height: 20),
      ],
    );
  }

  // String _formatTimer(DateTime? startedAt) {
  //   if (startedAt == null) return '15 min';
  //   final diff = DateTime.now().difference(startedAt);
  //   final minutes = diff.inMinutes;
  //   final seconds = diff.inSeconds % 60;
  //   return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} min';
  // }
}
