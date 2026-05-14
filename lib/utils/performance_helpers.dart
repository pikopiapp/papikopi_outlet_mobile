import 'dart:async';
import 'package:flutter/material.dart';

/// Debounce helper to prevent rapid function calls
class Debounce {
  final Duration delay;
  Timer? _timer;

  Debounce({this.delay = const Duration(milliseconds: 500)});

  void call(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    cancel();
  }
}

/// Throttle helper to limit function call frequency
class Throttle {
  final Duration delay;
  DateTime? _lastCallTime;
  Timer? _timer;

  Throttle({this.delay = const Duration(milliseconds: 500)});

  void call(VoidCallback callback) {
    final now = DateTime.now();
    
    if (_lastCallTime == null || 
        now.difference(_lastCallTime!).compareTo(delay) >= 0) {
      _lastCallTime = now;
      _timer?.cancel();
      callback();
    } else {
      _timer?.cancel();
      _timer = Timer(delay, () {
        _lastCallTime = DateTime.now();
        callback();
      });
    }
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    cancel();
  }
}

/// Helper to conditionally rebuild only when specific values change
class SelectiveRebuild<T> extends StatelessWidget {
  final T Function(BuildContext) selector;
  final Widget Function(BuildContext, T) builder;
  final bool Function(T, T)? shouldRebuild;

  const SelectiveRebuild({
    Key? key,
    required this.selector,
    required this.builder,
    this.shouldRebuild,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final value = selector(context);
    return builder(context, value);
  }
}

/// Response time tracker for debugging
class ResponseTimer {
  final String name;
  late Stopwatch _stopwatch;

  ResponseTimer(this.name) {
    _stopwatch = Stopwatch()..start();
  }

  void stop() {
    _stopwatch.stop();
    final ms = _stopwatch.elapsedMilliseconds;
    print('⏱️ [$name] took ${ms}ms');
  }

  void log(String event) {
    final ms = _stopwatch.elapsedMilliseconds;
    print('⏱️ [$name] $event at ${ms}ms');
  }
}

/// Cache with TTL (Time To Live)
class CacheWithTTL<T> {
  final Duration ttl;
  T? _value;
  DateTime? _timestamp;

  CacheWithTTL({required this.ttl});

  bool get isValid {
    if (_value == null || _timestamp == null) return false;
    return DateTime.now().difference(_timestamp!).compareTo(ttl) < 0;
  }

  T? get() {
    if (isValid) {
      print('✅ Cache hit');
      return _value;
    }
    print('❌ Cache miss or expired');
    return null;
  }

  void set(T value) {
    _value = value;
    _timestamp = DateTime.now();
    print('💾 Cache set');
  }

  void clear() {
    _value = null;
    _timestamp = null;
    print('🗑️ Cache cleared');
  }
}

/// Batch operations to reduce multiple function calls
class BatchOperation<T> {
  final Duration delay;
  final void Function(List<T>) onBatch;
  
  List<T> _queue = [];
  Timer? _timer;

  BatchOperation({
    required this.delay,
    required this.onBatch,
  });

  void add(T item) {
    _queue.add(item);
    _resetTimer();
  }

  void addMultiple(List<T> items) {
    _queue.addAll(items);
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(delay, _flush);
  }

  void _flush() {
    if (_queue.isNotEmpty) {
      final batch = _queue;
      _queue = [];
      onBatch(batch);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Lazy loading helper
class LazyLoader<T> {
  final Future<T> Function() loader;
  final Duration? cacheFor;
  
  T? _cachedValue;
  DateTime? _cacheTime;
  bool _isLoading = false;

  LazyLoader({required this.loader, this.cacheFor});

  Future<T> load() async {
    // Return cached value if still valid
    if (_cachedValue != null && _cacheTime != null && cacheFor != null) {
      if (DateTime.now().difference(_cacheTime!).compareTo(cacheFor!) < 0) {
        print('📦 Using cached value');
        return _cachedValue as T;
      }
    }

    // Prevent multiple concurrent loads
    if (_isLoading) {
      print('⏳ Already loading, waiting...');
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedValue as T;
    }

    _isLoading = true;
    try {
      _cachedValue = await loader();
      _cacheTime = DateTime.now();
      print('✅ Loaded fresh value');
      return _cachedValue as T;
    } finally {
      _isLoading = false;
    }
  }

  void clear() {
    _cachedValue = null;
    _cacheTime = null;
  }
}
