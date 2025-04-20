import 'package:webfeed/webfeed.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class RssService extends ChangeNotifier {
  List<RssItem> _items = [];
  List<RssItem> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  final List<String> _feedUrls = [
    'https://www.agriculture.com/rss',
    'https://www.farmprogress.com/rss',
    'https://www.agweb.com/rss',
  ];

  Future<void> fetchNews() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<RssItem> allItems = [];
      
      for (String url in _feedUrls) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final feed = RssFeed.parse(response.body);
            if (feed.items != null) {
              allItems.addAll(feed.items!);
            }
          }
        } catch (e) {
          print('Error fetching feed $url: $e');
          // Continue with other feeds even if one fails
        }
      }

      _items = allItems;
      _items.sort((a, b) => (b.pubDate ?? DateTime.now()).compareTo(a.pubDate ?? DateTime.now()));
      _error = null;
    } catch (e) {
      _error = 'Error fetching RSS feeds: $e';
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<RssItem> searchItems(String query) {
    if (query.isEmpty) return _items;
    return _items.where((item) {
      final title = item.title?.toLowerCase() ?? '';
      final description = item.description?.toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      return title.contains(searchQuery) || description.contains(searchQuery);
    }).toList();
  }

  List<RssItem> filterByCategory(String category) {
    if (category.isEmpty) return _items;
    return _items.where((item) {
      final itemCategory = item.categories?.first.value?.toLowerCase() ?? '';
      return itemCategory.contains(category.toLowerCase());
    }).toList();
  }

  Future<void> addCustomFeed(String url) async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final feed = RssFeed.parse(response.body);
        if (feed.items != null) {
          _items.addAll(feed.items!);
          _items.sort((a, b) => (b.pubDate ?? DateTime.now()).compareTo(a.pubDate ?? DateTime.now()));
        }
        _error = null;
      } else {
        _error = 'Failed to load feed: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error adding custom feed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearNews() {
    _items = [];
    notifyListeners();
  }
} 