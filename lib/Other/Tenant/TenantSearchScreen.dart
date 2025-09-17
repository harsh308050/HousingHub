import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/ShimmerHelper.dart';
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
  // Availability: default to available-only, user can include unavailable
  bool _includeUnavailable = false;

  final Map<String, List<String>> _filterOptions = {
    'gender': ['Male Only', 'Female Only', 'Both'],
    'propertyType': ['PG', 'Hostel', 'Apartment', 'House'],
    'amenities': [
      'WiFi',
      'Parking',
      'Laundry',
      'AC',
      'Mess Facility',
      'House Keeping',
      'Furnished',
      'Unfurnished',
    ],
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
      // Availability filter: by default show only available
      if (!_includeUnavailable) {
        if (p['isAvailable'] != true) return false;
      }
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
        if (_selectedFilters.contains('gender:Both') &&
            !maleAllowed &&
            !femaleAllowed) genderOk = false;
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

  // Apply sorting based on current _sort option
  List<Map<String, dynamic>> _applySort(List<Map<String, dynamic>> input) {
    final list = List<Map<String, dynamic>>.from(input);
    switch (_sort) {
      case 'Newest':
        list.sort((a, b) {
          final ad = _asDateTime(a['createdAt']);
          final bd = _asDateTime(b['createdAt']);
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1; // nulls last
          if (bd == null) return -1;
          return bd.compareTo(ad); // newest first
        });
        break;
      case 'Price: Low to High':
        list.sort((a, b) =>
            _parsePrice(a['price']).compareTo(_parsePrice(b['price'])));
        break;
      case 'Price: High to Low':
        list.sort((a, b) =>
            _parsePrice(b['price']).compareTo(_parsePrice(a['price'])));
        break;
      case 'Relevance':
      default:
        final q = _searchCtrl.text.trim().toLowerCase();
        if (q.isEmpty) {
          // Keep server/default order when no query
          return list;
        }
        list.sort((a, b) {
          final sa = _relevanceScore(a, q);
          final sb = _relevanceScore(b, q);
          if (sb != sa) return sb.compareTo(sa); // higher first
          // tie-breaker: price low to high
          return _parsePrice(a['price']).compareTo(_parsePrice(b['price']));
        });
    }
    return list;
  }

  int _relevanceScore(Map<String, dynamic> p, String q) {
    int s = 0;
    String str(dynamic v) => (v?.toString().toLowerCase() ?? '');
    if (str(p['title']).contains(q)) s += 5;
    if (str(p['address']).contains(q)) s += 4;
    if (str(p['city']).contains(q)) s += 3;
    if (str(p['state']).contains(q)) s += 2;
    if (str(p['description']).contains(q)) s += 1;
    if (str(p['propertyType']).contains(q)) s += 1;
    if (str(p['roomType']).contains(q)) s += 1;
    return s;
  }

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  void _showFiltersSheet() {
    final width = MediaQuery.of(context).size.width;
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
                Row(
                  spacing: (width / 3) - 30,
                  children: [
                    IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_ios)),
                    Text('Filters',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 24),
                // Availability toggle
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Availability',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      const Spacer(),
                      Row(children: [
                        Text('Include Unavailable',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 12)),
                        Switch(
                          value: _includeUnavailable,
                          activeColor: AppConfig.primaryColor,
                          onChanged: (v) => setM(() => _includeUnavailable = v),
                        ),
                      ])
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Price Range',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
                RangeSlider(
                  activeColor: AppConfig.primaryColor,
                  values: _priceRange,
                  min: 0,
                  max: _maxPriceFound,
                  divisions: 20,
                  labels: RangeLabels('₹${_priceRange.start.round()}',
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
                        _buildFilterGroup(
                            'Property Type', 'propertyType', setM),
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
                            _includeUnavailable = false; // reset to default
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: AppConfig.primaryColor),
                        ),
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
                        child: const Text('Apply',
                            style: TextStyle(color: Colors.white)),
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
    final sorted = _applySort(filtered);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _buildSearchBar(),
            ),
            _buildCategoryFiltersRow(),
            const SizedBox(height: 12),
            _buildActiveFiltersRow(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text('${sorted.length} Properties...',
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
                  ? ShimmerHelper.searchResultsShimmer()
                  : RefreshIndicator(
                      onRefresh: _fetchProperties,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: sorted.length,
                        itemBuilder: (c, i) => _PropertyResultCard(
                          data: sorted[i],
                          onTap: () => _openDetail(sorted[i]),
                        ),
                      ),
                    ),
            )
          ],
        ),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          GestureDetector(
            onTap: _showFiltersSheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.tune, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFiltersRow() {
    final categories = [
      {'label': 'Price', 'icon': Icons.payments_outlined},
      {'label': 'Gender', 'icon': Icons.wc_outlined},
      {'label': 'Type', 'icon': Icons.home_work_outlined},
      {'label': 'Amenities', 'icon': Icons.category_outlined},
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (c, i) {
          final item = categories[i];
          return GestureDetector(
            onTap: _showFiltersSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E6EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Icon(item['icon'] as IconData,
                      size: 16, color: AppConfig.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    item['label'] as String,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: categories.length,
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
    if (_includeUnavailable) {
      chips.add(
        _RemovableChip(
          label: 'Include Unavailable',
          onRemoved: () => setState(() => _includeUnavailable = false),
        ),
      );
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
            for (final opt in [
              'Relevance',
              'Newest',
              'Price: Low to High',
              'Price: High to Low'
            ])
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

class _PropertyResultCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _PropertyResultCard({required this.data, required this.onTap});

  @override
  State<_PropertyResultCard> createState() => _PropertyResultCardState();
}

class _PropertyResultCardState extends State<_PropertyResultCard> {
  bool _saved = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final id = widget.data['id']?.toString();
      if (user?.email != null && id != null) {
        final val = await Api.isPropertySaved(
            tenantEmail: user!.email!, propertyId: id);
        if (mounted) setState(() => _saved = val);
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _toggle() async {
    final user = FirebaseAuth.instance.currentUser;
    final id = widget.data['id']?.toString();
    if (user?.email == null || id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to save properties')));
      return;
    }
    final prev = _saved;
    setState(() => _saved = !prev);
    try {
      if (!prev) {
        await Api.savePropertyForTenant(
            tenantEmail: user!.email!,
            propertyId: id,
            propertyData: widget.data);
      } else {
        await Api.removeSavedProperty(
            tenantEmail: user!.email!, propertyId: id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saved = prev);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is num) return price.toDouble();
    final s = price.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final image = (data['images'] is List && data['images'].isNotEmpty)
        ? data['images'][0]
        : 'https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg';
    final priceNum = _parsePrice(data['price']);
    final priceStr = '₹${priceNum.toStringAsFixed(0)}';
    // Ratings removed
    final isNew = data['createdAt'] is Timestamp
        ? DateTime.now()
                .difference((data['createdAt'] as Timestamp).toDate())
                .inDays <
            14
        : false;
    final available = data['isAvailable'] == true;
    final genderBadge =
        data['femaleAllowed'] == true && data['maleAllowed'] == true
            ? 'Open to All'
            : data['femaleAllowed'] == true
                ? 'Female'
                : data['maleAllowed'] == true
                    ? 'Male'
                    : '';
    final bedrooms = data['bedrooms'];
    final typeLabel = bedrooms != null
        ? '${bedrooms.toString()} BHK'
        : (data['propertyType']?.toString() ?? '');
    final distance = data['distanceFromMetro']?.toString();
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E6EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 10,
                    children: [
                      if (available)
                        _Badge(label: 'Available', color: Colors.green.shade600)
                      else
                        _Badge(
                            label: 'Unavailable', color: Colors.red.shade600),
                      if (isNew)
                        _Badge(label: 'New', color: Colors.orange.shade600),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _checking ? null : _toggle,
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
                      child: Icon(
                        _saved ? Icons.bookmark : Icons.bookmark_border,
                        size: 20,
                        color: _saved ? AppConfig.primaryColor : Colors.black87,
                      ),
                    ),
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
                              typeLabel,
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
                      // Ratings removed
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['address']?.toString() ?? 'Location',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Row(children: const [
                        Icon(Icons.wifi, size: 14),
                        SizedBox(width: 4),
                        Text('Wi-Fi', style: TextStyle(fontSize: 11))
                      ]),
                      const SizedBox(width: 14),
                      Row(children: const [
                        Icon(Icons.cleaning_services, size: 14),
                        SizedBox(width: 4),
                        Text('House Keeping', style: TextStyle(fontSize: 11))
                      ]),
                      const SizedBox(width: 14),
                      Row(children: const [
                        Icon(Icons.restaurant, size: 14),
                        SizedBox(width: 4),
                        Text('Mess', style: TextStyle(fontSize: 11))
                      ]),
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
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      const Spacer(),
                      if (distance != null && distance.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(distance,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54)),
                        ),
                      if (genderBadge.isNotEmpty)
                        _Badge(
                            label: genderBadge, color: Colors.indigo.shade600),
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
        color: Colors.white,
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
