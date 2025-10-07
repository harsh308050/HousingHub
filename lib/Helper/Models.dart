import 'package:flutter/material.dart';
import 'package:housinghub/config/AppConfig.dart';

class Models {
  static void showMsgSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppConfig.infoColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppConfig.dangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppConfig.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  static void showWarningSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppConfig.warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  static void showInfoSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppConfig.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Formats a number according to Indian currency system
  /// Examples: 3000 -> "3,000", 300000 -> "3,00,000", 1200000 -> "12,00,000"
  static String formatIndianCurrency(dynamic amount) {
    if (amount == null) return '0';
    
    String amountStr = amount.toString().trim();
    
    // Remove any existing commas and handle decimal points
    amountStr = amountStr.replaceAll(',', '');
    
    // Handle decimal part
    String decimalPart = '';
    if (amountStr.contains('.')) {
      List<String> parts = amountStr.split('.');
      amountStr = parts[0];
      if (parts[1].isNotEmpty && parts[1] != '0' && parts[1] != '00') {
        decimalPart = '.${parts[1]}';
      }
    }
    
    // If the number has 3 or fewer digits, no formatting needed
    if (amountStr.length <= 3) {
      return '$amountStr$decimalPart';
    }
    
    // Indian number system: first group from right is 3 digits, then groups of 2
    String result = '';
    int length = amountStr.length;
    
    // Add the last 3 digits (rightmost)
    result = amountStr.substring(length - 3);
    
    // Add remaining digits in groups of 2 from right to left
    for (int i = length - 3; i > 0; i -= 2) {
      int start = (i - 2 < 0) ? 0 : i - 2;
      String group = amountStr.substring(start, i);
      result = '$group,$result';
    }
    
    return '$result$decimalPart';
  }
}
