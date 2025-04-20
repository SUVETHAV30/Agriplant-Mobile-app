import 'package:flutter/foundation.dart';

class NewsItem {
  final String title;
  final String description;
  final DateTime pubDate;
  final String link;
  final List<String> categories;

  NewsItem({
    required this.title,
    required this.description,
    required this.pubDate,
    required this.link,
    required this.categories,
  });
}

class NewsService extends ChangeNotifier {
  List<NewsItem> _news = [];
  List<NewsItem> get news => _news;
  String? _error;
  String? get error => _error;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _currentCategory = 'All';
  String get currentCategory => _currentCategory;

  Future<void> fetchNews() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      _news = [
        NewsItem(
          title: 'Crop Prices Reach Record High',
          description: 'Global demand and supply chain issues have pushed crop prices to record levels.',
          pubDate: DateTime.now(),
          link: 'https://example.com/news/1',
          categories: ['Crops', 'Market'],
        ),
        NewsItem(
          title: 'New Sustainable Farming Techniques',
          description: 'Researchers develop innovative methods to reduce water usage in agriculture.',
          pubDate: DateTime.now().subtract(const Duration(hours: 1)),
          link: 'https://example.com/news/2',
          categories: ['Technology', 'Sustainability'],
        ),
        NewsItem(
          title: 'Livestock Health Monitoring App',
          description: 'New mobile app helps farmers track livestock health and productivity.',
          pubDate: DateTime.now().subtract(const Duration(hours: 2)),
          link: 'https://example.com/news/3',
          categories: ['Livestock', 'Technology'],
        ),
        NewsItem(
          title: 'Weather Patterns Impact Harvest',
          description: 'Unusual weather patterns are affecting crop yields across the region.',
          pubDate: DateTime.now().subtract(const Duration(hours: 3)),
          link: 'https://example.com/news/4',
          categories: ['Crops', 'Weather'],
        ),
        NewsItem(
          title: 'Organic Farming Certification Changes',
          description: 'New regulations for organic farming certification announced.',
          pubDate: DateTime.now().subtract(const Duration(hours: 4)),
          link: 'https://example.com/news/5',
          categories: ['Crops', 'Regulation'],
        ),
      ];

      _error = null;
    } catch (e) {
      _error = 'Error fetching news: $e';
      _news = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterByCategory(String category) {
    _currentCategory = category;
    notifyListeners();
  }

  List<NewsItem> get filteredNews {
    if (_currentCategory == 'All') {
      return _news;
    }
    return _news.where((item) => item.categories.contains(_currentCategory)).toList();
  }
} 