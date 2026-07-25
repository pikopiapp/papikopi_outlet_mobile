import 'package:flutter/material.dart';

class InvestorConstants {
  // Banks
  static const List<Map<String, String>> banks = [
    {'code': 'bca', 'name': 'BCA', 'icon': '🏦'},
    {'code': 'mandiri', 'name': 'Mandiri', 'icon': '🏦'},
    {'code': 'bni', 'name': 'BNI', 'icon': '🏦'},
    {'code': 'cimb', 'name': 'CIMB Niaga', 'icon': '🏦'},
  ];

  // E-Wallets
  static const List<Map<String, String>> eWallets = [
    {'code': 'gopay', 'name': 'GoPay', 'icon': '📱'},
    {'code': 'ovo', 'name': 'OVO', 'icon': '📱'},
    {'code': 'dana', 'name': 'DANA', 'icon': '📱'},
  ];

  // Bank names mapping
  static const Map<String, String> bankNames = {
    'bca': 'BCA Transfer',
    'mandiri': 'Mandiri Transfer',
    'bni': 'BNI Transfer',
    'cimb': 'CIMB Transfer',
  };

  // Wallet names mapping
  static const Map<String, String> walletNames = {
    'gopay': 'GoPay',
    'ovo': 'OVO',
    'dana': 'DANA',
  };

  // Status mapping
  static String getStatusDisplay(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'verified':
        return 'Verified';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'verified':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static String getMethodDisplay(String? method, String? methodType) {
    if (method == 'bank_transfer') {
      return bankNames[methodType] ?? 'Bank Transfer';
    } else if (method == 'e_wallet') {
      return walletNames[methodType] ?? 'E-Wallet';
    }
    return 'Unknown';
  }

  // Minimum withdrawal amount
  static const double minWithdrawalAmount = 100000;
  static const double withdrawalFee = 5000;
}