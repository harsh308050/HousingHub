import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Other/Tenant/TenantPropertyDetail.dart';

class TenantSearchTab extends StatefulWidget {
  const TenantSearchTab({Key? key}) : super(key: key);

  @override
  State<TenantSearchTab> createState() => _TenantSearchTabState();
}

class _TenantSearchTabState extends State<TenantSearchTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _all = [];
  String _sort = 'Relevance';
  final Set<String> _selectedFilters = {};
  RangeValues _priceRange = const RangeValues(3000, 20000);
  double _maxPriceFound = 20000;

  final Map<String, List<String>> _filterOptions = {
    'gender': ['Male Only', 'Female Only', 'Both'],
    'propertyType': ['PG', 'Hostel', 'Apartment', 'House'],
    'amenities': ['WiFi', 'Laundry', 'AC', 'Mess Facility', 'Parking'],
  };

  @override
  void initState() {
    super.initState();
    _fetchProperties();
    _searchCtrl.addListener(() => setState(() {}));
  }

  Future<void> _fetchProperties() async {
    setState(() => _loading = true);
    try {
      final list = await Api.getAllProperties();
      double maxPrice = 0;
      for (var p in list) {
        final priceVal = _parsePrice(p['price']);
        if (priceVal > maxPrice) maxPrice = priceVal;
      }
      if (maxPrice < 5000) maxPrice = 5000;
      setState(() {
        _all = list;
        _maxPriceFound = maxPrice;
        // Reset range to full span after first fetch
        _priceRange = RangeValues(0, maxPrice);
      });
      if (list.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No properties found.')), // dev feedback
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load properties: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    final s = price.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _all.where((p) {
      final priceVal = _parsePrice(p['price']);
      if (priceVal < _priceRange.start || priceVal > _priceRange.end) {
        return false;
      }
      // Gender filter
      bool genderOk = true;
      if (_selectedFilters.any((f) => f.startsWith('gender:'))) {
        final femaleAllowed = p['femaleAllowed'] == true;
        final maleAllowed = p['maleAllowed'] == true;
        if (_selectedFilters.contains('gender:Male Only') && !maleAllowed)
          genderOk = false;
        if (_selectedFilters.contains('gender:Female Only') && !femaleAllowed)
          genderOk = false;
        if (_selectedFilters.contains('gender:Both') && !maleAllowed && !femaleAllowed)
          genderOk = false;
      }
      if (!genderOk) return false;

      // Property type
      if (_selectedFilters.any((f) => f.startsWith('propertyType:'))) {
        final type = (p['propertyType'] ?? '').toString();
        if (!_selectedFilters.contains('propertyType:$type')) {
          return false;
        }
      }
      // Amenities
      if (_selectedFilters.any((f) => f.startsWith('amenities:'))) {
        final amenities = (p['amenities'] is List)
            ? List<String>.from(p['amenities'].map((e) => e.toString()))
            : <String>[];
        final needed = _selectedFilters
            .where((e) => e.startsWith('amenities:'))
            .map((e) => e.split(':')[1])
            .toList();
        for (final n in needed) {
          if (!amenities.contains(n)) return false;
        }
      }
      if (q.isEmpty) return true;
      final haystack = [
        p['title'],
        p['address'],
        p['city'],
        p['state'],
        p['description'],
        p['propertyType'],
        p['roomType']
      ].whereType<String>().map((e) => e.toLowerCase()).join(' ');
      return haystack.contains(q);
    }).toList();
  }

  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (context, setM) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                const Text('Filters',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Price Range',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
                RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: _maxPriceFound,
                  divisions: 20,
                  labels: RangeLabels(
                      '₹${_priceRange.start.round()}',
                      '₹${_priceRange.end.round()}'),
                  onChanged: (v) => setM(() => _priceRange = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterGroup('Gender', 'gender', setM),
                        _buildFilterGroup('Property Type', 'propertyType', setM),
                        _buildFilterGroup('Amenities', 'amenities', setM),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilters.clear();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFilterGroup(String title, String key, StateSetter setM) {
    final options = _filterOptions[key] ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((o) {
              final tag = '$key:$o';
              final selected = _selectedFilters.contains(tag);
              return FilterChip(
                label: Text(o),
                selected: selected,
                onSelected: (v) => setM(() {
                  if (v) {
                    // For gender or propertyType allow multi but simple
                    _selectedFilters.add(tag);
                  } else {
                    _selectedFilters.remove(tag);
                  }
                }),
                selectedColor: AppConfig.primaryColor.withOpacity(.15),
                checkmarkColor: AppConfig.primaryColor,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _buildSearchBar(),
            ),
            _buildActiveFiltersRow(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('${filtered.length} Properties...',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const Spacer(),
                  InkWell(
                    onTap: _showSortSheet,
                    child: Row(
                      children: [
                        Text('Sort: $_sort',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 18)
                      ],
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchProperties,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (c, i) => _PropertyResultCard(
                          data: filtered[i],
                          onTap: () => _openDetail(filtered[i]),
                        ),
                      ),
                    ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFiltersSheet,
        backgroundColor: AppConfig.primaryColor,
        child: const Icon(Icons.tune, color: Colors.white),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TenantPropertyDetail(
          propertyId: p['id'],
          propertyData: p,
          price: p['price']?.toString(),
          location: p['address']?.toString(),
          imagePath: (p['images'] is List && p['images'].isNotEmpty)
              ? p['images'][0]
              : null,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by location, area or landmark',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          InkWell(
            onTap: _showFiltersSheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.filter_list,
                  size: 20, color: AppConfig.primaryColor),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActiveFiltersRow() {
    final chips = <Widget>[];
    for (final f in _selectedFilters) {
      final parts = f.split(':');
      if (parts.length != 2) continue;
      chips.add(_RemovableChip(
        label: parts[1],
        onRemoved: () => setState(() => _selectedFilters.remove(f)),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16),
        scrollDirection: Axis.horizontal,
        children: chips,
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Sort By',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final opt in ['Relevance', 'Newest', 'Price: Low to High', 'Price: High to Low'])
              ListTile(
                title: Text(opt),
                trailing: _sort == opt
                    ? const Icon(Icons.check, color: AppConfig.primaryColor)
                    : null,
                onTap: () {
                  setState(() => _sort = opt);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemoved;
  const _RemovableChip({required this.label, required this.onRemoved});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppConfig.primaryColor.withOpacity(.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppConfig.primaryColor, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemoved,
            child: const Icon(Icons.close, size: 16, color: Colors.black54),
          )
        ],
      ),
    );
  }
}

class _PropertyResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _PropertyResultCard({required this.data, required this.onTap});

  double _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    final s = price.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final image = (data['images'] is List && data['images'].isNotEmpty)
        ? data['images'][0]
        : 'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg';
    final priceNum = _parsePrice(data['price']);
    final priceStr = '₹${priceNum.toStringAsFixed(0)}';
    final rating = data['rating'];
    final isNew = data['createdAt'] is Timestamp
        ? DateTime.now().difference((data['createdAt'] as Timestamp).toDate()).inDays < 14
        : false;
    final available = data['isAvailable'] == true;
    final genderBadge = data['femaleAllowed'] == true && data['maleAllowed'] == true
        ? 'Both'
        : data['femaleAllowed'] == true
            ? 'Female'
            : data['maleAllowed'] == true
                ? 'Male'
                : '';
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: AspectRatio(
                    aspectRatio: 16/9,
                    child: Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (available)
                        _Badge(label: 'Verified', color: Colors.green.shade600),
                      if (isNew)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _Badge(label: 'New', color: Colors.orange.shade600),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(Icons.bookmark_border, size: 20),
                  ),
                )
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['propertyType']?.toString().toUpperCase() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: .5,
                                fontWeight: FontWeight.w600,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['title']?.toString() ?? 'Property',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(rating.toString(),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['address']?.toString() ?? 'Location',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    children: [
                      Row(children: const [Icon(Icons.wifi, size: 16), SizedBox(width:4), Text('Wi-Fi', style: TextStyle(fontSize: 12))]),
                      Row(children: const [Icon(Icons.cleaning_services, size: 16), SizedBox(width:4), Text('House Keeping', style: TextStyle(fontSize: 12))]),
                      Row(children: const [Icon(Icons.restaurant, size: 16), SizedBox(width:4), Text('Mess', style: TextStyle(fontSize: 12))]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        priceStr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('/month',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const Spacer(),
                      if (genderBadge.isNotEmpty)
                        _Badge(label: genderBadge, color: Colors.indigo.shade600),
                      const SizedBox(width: 6),
                      _Badge(
                          label: data['roomType']?.toString() ?? 'Room',
                          color: Colors.purple.shade600),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
