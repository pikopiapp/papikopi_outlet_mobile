import 'package:uuid/uuid.dart';

/// Demo Service - Provides mock data for testing without Supabase
class DemoService {
  static final uuid = Uuid();

  // Mock Users
  static final demoUsers = [
    {
      'id': 'user-1',
      'email': 'barista@papikopi.com',
      'name': 'Budi Santoso',
      'role': 'barista',
      'outlet_id': 'outlet-1',
      'created_at': DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
    },
    {
      'id': 'user-2',
      'email': 'manager@papikopi.com',
      'name': 'Siti Nurhayati',
      'role': 'manager',
      'outlet_id': 'outlet-1',
      'created_at': DateTime.now().subtract(Duration(days: 60)).toIso8601String(),
    },
    {
      'id': 'user-3',
      'email': 'barista2@papikopi.com',
      'name': 'Ahmad Rahman',
      'role': 'barista',
      'outlet_id': 'outlet-2',
      'created_at': DateTime.now().subtract(Duration(days: 45)).toIso8601String(),
    },
  ];

  // Mock Products
  static final demoProducts = [
    {
      'id': 'prod-1',
      'name': 'Espresso',
      'category': 'kopi',
      'price': 15000,
      'image_url': null,
      'created_at': DateTime.now().subtract(Duration(days: 100)).toIso8601String(),
    },
    {
      'id': 'prod-2',
      'name': 'Cappuccino',
      'category': 'kopi',
      'price': 25000,
      'image_url': null,
      'created_at': DateTime.now().subtract(Duration(days: 100)).toIso8601String(),
    },
    {
      'id': 'prod-3',
      'name': 'Latte',
      'category': 'kopi',
      'price': 28000,
      'image_url': null,
      'created_at': DateTime.now().subtract(Duration(days: 100)).toIso8601String(),
    },
    {
      'id': 'prod-4',
      'name': 'Americano',
      'category': 'kopi',
      'price': 18000,
      'image_url': null,
      'created_at': DateTime.now().subtract(Duration(days: 100)).toIso8601String(),
    },
    {
      'id': 'prod-5',
      'name': 'Iced Coffee',
      'category': 'kopi',
      'price': 22000,
      'image_url': null,
      'created_at': DateTime.now().subtract(Duration(days: 100)).toIso8601String(),
    },
  ];

  // Mock Sales Records
  static List<Map<String, dynamic>> generateDemoSales({
    required String outletId,
    required int daysBack,
  }) {
    final sales = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 0; i < daysBack; i++) {
      final date = now.subtract(Duration(days: i));
      final dailySales = 5 + (i % 10); // 5-15 sales per day

      for (int j = 0; j < dailySales; j++) {
        sales.add({
          'id': uuid.v4(),
          'outlet_id': outletId,
          'total': 50000 + (i * 1000) + (j * 5000),
          'payment_method': j % 3 == 0 ? 'cash' : j % 3 == 1 ? 'card' : 'transfer',
          'created_at': DateTime(date.year, date.month, date.day, 8 + j, j * 5)
              .toIso8601String(),
        });
      }
    }

    return sales;
  }

  // Mock Sales Items
  static List<Map<String, dynamic>> generateDemoSalesItems() {
    return [
      {
        'id': uuid.v4(),
        'sale_id': 'sale-1',
        'product_id': 'prod-1',
        'quantity': 2,
        'price': 15000,
        'created_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
      },
      {
        'id': uuid.v4(),
        'sale_id': 'sale-1',
        'product_id': 'prod-2',
        'quantity': 1,
        'price': 25000,
        'created_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
      },
      {
        'id': uuid.v4(),
        'sale_id': 'sale-2',
        'product_id': 'prod-3',
        'quantity': 3,
        'price': 28000,
        'created_at': DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
      },
    ];
  }

  // Mock Private Messages
  static List<Map<String, dynamic>> generateDemoPrivateMessages() {
    return [
      {
        'id': uuid.v4(),
        'sender_id': 'user-1',
        'sender_name': 'Budi Santoso',
        'recipient_id': 'user-2',
        'recipient_name': 'Siti Nurhayati',
        'message': 'Halo, stok espresso habis. Perlu order lagi',
        'created_at': DateTime.now().subtract(Duration(hours: 3)).toIso8601String(),
        'read_at': null,
      },
      {
        'id': uuid.v4(),
        'sender_id': 'user-2',
        'sender_name': 'Siti Nurhayati',
        'recipient_id': 'user-1',
        'recipient_name': 'Budi Santoso',
        'message': 'Baik, akan saya pesan hari ini. Tunggu update',
        'created_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
        'read_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
      },
      {
        'id': uuid.v4(),
        'sender_id': 'user-1',
        'sender_name': 'Budi Santoso',
        'recipient_id': 'user-2',
        'recipient_name': 'Siti Nurhayati',
        'message': 'Terima kasih bu!',
        'created_at': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
        'read_at': null,
      },
    ];
  }

  // Mock Group Chat Messages
  static List<Map<String, dynamic>> generateDemoGroupChatMessages() {
    return [
      {
        'id': uuid.v4(),
        'group_chat_id': 'group-1',
        'sender_id': 'user-1',
        'sender_name': 'Budi Santoso',
        'sender_role': 'barista',
        'message': 'Pagi semua! Hari ini cafe penuh sekali',
        'created_at': DateTime.now().subtract(Duration(hours: 4)).toIso8601String(),
      },
      {
        'id': uuid.v4(),
        'group_chat_id': 'group-1',
        'sender_id': 'user-2',
        'sender_name': 'Siti Nurhayati',
        'sender_role': 'manager',
        'message': 'Bagus! Berarti penjualan hari ini bagus',
        'created_at': DateTime.now().subtract(Duration(hours: 3)).toIso8601String(),
      },
      {
        'id': uuid.v4(),
        'group_chat_id': 'group-1',
        'sender_id': 'user-3',
        'sender_name': 'Ahmad Rahman',
        'sender_role': 'barista',
        'message': 'Siap! Semua produk sudah disediakan dengan baik',
        'created_at': DateTime.now().subtract(Duration(hours: 3)).toIso8601String(),
      },
    ];
  }

  // Mock Low Stock Products
  static List<Map<String, dynamic>> generateDemoLowStockProducts() {
    return [
      {
        'id': 'prod-1',
        'name': 'Espresso Beans',
        'current_stock': 2,
        'minimum_stock': 5,
        'category': 'ingredients',
      },
      {
        'id': 'prod-2',
        'name': 'Milk',
        'current_stock': 1,
        'minimum_stock': 3,
        'category': 'ingredients',
      },
      {
        'id': 'prod-3',
        'name': 'Sugar',
        'current_stock': 4,
        'minimum_stock': 10,
        'category': 'ingredients',
      },
    ];
  }

  // Mock Announcements
  static List<Map<String, dynamic>> generateDemoAnnouncements() {
    return [
      {
        'id': uuid.v4(),
        'title': 'Update Menu Baru',
        'message': 'Mulai hari ini ada menu baru: Affogato Special',
        'created_at': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
      },
      {
        'id': uuid.v4(),
        'title': 'Maintenance Database',
        'message': 'Database akan maintenance Jumat malam 22:00 - 23:00 WIB',
        'created_at': DateTime.now().subtract(Duration(days: 3)).toIso8601String(),
      },
      {
        'id': uuid.v4(),
        'title': 'Promo Hari Ini',
        'message': 'Buy 2 Get 1 Free untuk Americano hari ini saja',
        'created_at': DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
      },
    ];
  }

  // Mock Yesterday Sales Data (for analytics)
  static Map<String, dynamic> generateDemoYesterdaySalesData() {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return {
      'date': yesterday.toIso8601String(),
      'total_sales': 1250000,
      'transaction_count': 42,
      'average_transaction': 29761,
      'top_product': 'Cappuccino',
      'top_product_qty': 15,
    };
  }

  // Mock Today Sales Data (for analytics)
  static Map<String, dynamic> generateDemoTodaySalesData() {
    return {
      'date': DateTime.now().toIso8601String(),
      'total_sales': 1580000,
      'transaction_count': 51,
      'average_transaction': 30980,
      'top_product': 'Latte',
      'top_product_qty': 18,
    };
  }

  // Mock Recent Transactions
  static List<Map<String, dynamic>> generateDemoRecentTransactions({
    int count = 5,
  }) {
    final transactions = <Map<String, dynamic>>[];
    for (int i = 0; i < count; i++) {
      transactions.add({
        'id': uuid.v4(),
        'total': 50000 + (i * 12000),
        'payment_method': i % 3 == 0 ? 'cash' : i % 3 == 1 ? 'card' : 'transfer',
        'item_count': 2 + (i % 4),
        'created_at': DateTime.now().subtract(Duration(minutes: (i + 1) * 10)).toIso8601String(),
      });
    }
    return transactions;
  }

  // Mock Outlets
  static final demoOutlets = [
    {
      'id': 'outlet-1',
      'name': 'Papikopi - Pusat',
      'location': 'Jl. Merdeka No. 1',
      'phone': '021-1234567',
      'created_at': DateTime.now().subtract(Duration(days: 365)).toIso8601String(),
    },
    {
      'id': 'outlet-2',
      'name': 'Papikopi - Cabang',
      'location': 'Jl. Ahmad Yani No. 5',
      'phone': '021-7654321',
      'created_at': DateTime.now().subtract(Duration(days: 180)).toIso8601String(),
    },
  ];

  // Mock Staff Data
  static final demoStaff = [
    {
      'id': 'user-1',
      'name': 'Budi Santoso',
      'role': 'barista',
      'outlet_id': 'outlet-1',
      'email': 'barista@papikopi.com',
      'status': 'active',
      'created_at': DateTime.now().subtract(Duration(days: 90)).toIso8601String(),
    },
    {
      'id': 'user-2',
      'name': 'Siti Nurhayati',
      'role': 'manager',
      'outlet_id': 'outlet-1',
      'email': 'manager@papikopi.com',
      'status': 'active',
      'created_at': DateTime.now().subtract(Duration(days: 180)).toIso8601String(),
    },
  ];
}
