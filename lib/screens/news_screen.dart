import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/news_service.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({Key? key}) : super(key: key);

  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsService>().fetchNews();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agricultural News'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<NewsService>().fetchNews(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search News',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  _buildCategoryChip('All'),
                  _buildCategoryChip('Crops'),
                  _buildCategoryChip('Livestock'),
                  _buildCategoryChip('Technology'),
                  _buildCategoryChip('Market'),
                  _buildCategoryChip('Sustainability'),
                  _buildCategoryChip('Weather'),
                  _buildCategoryChip('Regulation'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Consumer<NewsService>(
              builder: (context, newsService, child) {
                if (newsService.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (newsService.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          newsService.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => newsService.fetchNews(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredNews = newsService.filteredNews.where((item) {
                  final title = item.title.toLowerCase();
                  final description = item.description.toLowerCase();
                  return title.contains(_searchQuery) ||
                      description.contains(_searchQuery);
                }).toList();

                if (filteredNews.isEmpty) {
                  return const Center(
                    child: Text('No news found'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => newsService.fetchNews(),
                  child: ListView.builder(
                    itemCount: filteredNews.length,
                    itemBuilder: (context, index) {
                      final item = filteredNews[index];
                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: ListTile(
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(item.description),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                children: item.categories.map((category) {
                                  return Chip(
                                    label: Text(category),
                                    backgroundColor: Colors.green.shade100,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(item.pubDate),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _launchUrl(item.link),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Consumer<NewsService>(
      builder: (context, newsService, child) {
        final isSelected = newsService.currentCategory == category;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: FilterChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                newsService.filterByCategory(category);
              }
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    try {
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return date.toString();
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }
} 