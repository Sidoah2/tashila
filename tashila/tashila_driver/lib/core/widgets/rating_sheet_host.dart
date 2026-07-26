import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../features/home/client_rating_sheet.dart';

bool _isClientRatingShowing = false;

/// Presents the post-trip client rating flow as a mandatory, non-dismissible floating dialog.
Future<void> showRequiredClientRatingSheet(BuildContext context) async {
  if (_isClientRatingShowing) return;
  _isClientRatingShowing = true;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            elevation: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                    ),
                    child: const ClientRatingSheetContent(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  } finally {
    _isClientRatingShowing = false;
  }
}
