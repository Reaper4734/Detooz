import 'package:flutter/material.dart';
import '../../contracts/scan_view_model.dart';
import '../theme/app_colors.dart';

class PlatformIcon extends StatelessWidget {
  final PlatformType platform;
  final double size;
  
  const PlatformIcon({
    super.key, 
    required this.platform,
    this.size = 24.0,
  });
  
  @override
  Widget build(BuildContext context) {
    return Icon(
      _getIcon(),
      color: _getColor(),
      size: size,
    );
  }
  
  IconData _getIcon() {
    // Note: In a real app we might use custom assets or FontAwesome
    // Using default Material icons as proxies for now
    switch (platform) {
      case PlatformType.sms: return Icons.sms;
      case PlatformType.whatsapp: return Icons.chat;
      case PlatformType.telegram: return Icons.send; // Closest approximation
    }
  }
  
  Color _getColor() {
    switch (platform) {
      case PlatformType.sms: return AppColors.sms;
      case PlatformType.whatsapp: return AppColors.whatsapp;
      case PlatformType.telegram: return AppColors.telegram;
    }
  }
}
