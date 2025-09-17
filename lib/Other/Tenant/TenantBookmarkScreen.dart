import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:housinghub/Helper/API.dart';
import 'package:housinghub/Helper/ShimmerHelper.dart';
import 'package:housinghub/Other/Tenant/TenantPropertyDetail.dart';
import 'package:housinghub/config/AppConfig.dart';

class TenantBookmarksTab extends StatefulWidget {
  const TenantBookmarksTab({super.key});

  @override
  State<TenantBookmarksTab> createState() => _TenantBookmarksTabState();
}

class _TenantBookmarksTabState extends State<TenantBookmarksTab> {
  User? get _user => FirebaseAuth.instance.currentUser;
  bool _gridMode = true;

  @override
  Widget build(BuildContext context) {
    if (_user?.email == null) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text('Saved Listings'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.login, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Sign in to view saved properties'),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Api.streamSavedProperties(_user!.email!),
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.hasError ? snapshot.error?.toString() : null;
        final docs = snapshot.data?.docs ?? [];
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            title: const Text('Saved Listings',
                style: TextStyle(fontWeight: FontWeight.w600)),
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          body: waiting
              ? ShimmerHelper.savedListingsShimmer(gridMode: _gridMode)
              : error != null
                  ? Center(child: Text('Error: $error'))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${docs.length} saved listings',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87)),
                              const Spacer(),
                              _ViewToggle(
                                grid: true,
                                selected: _gridMode,
                                onTap: () => setState(() => _gridMode = true),
                              ),
                              const SizedBox(width: 8),
                              _ViewToggle(
                                grid: false,
                                selected: !_gridMode,
                                onTap: () => setState(() => _gridMode = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (docs.isEmpty)
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bookmark_border,
                                        size: 72, color: Colors.grey[350]),
                                    const SizedBox(height: 16),
                                    const Text('No saved properties yet',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('Properties you save will appear here',
                                        style:
                                            TextStyle(color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: _gridMode
                                  ? GridView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.70,
                                      ),
                                      itemCount: docs.length,
                                      itemBuilder: (c, i) => _SavedCard(
                                        data: docs[i].data(),
                                        onOpen: () => _open(docs[i].data()),
                                        onToggleSave: () => _remove(docs[i]),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      itemCount: docs.length,
                                      itemBuilder: (c, i) => _SavedListTile(
                                        data: docs[i].data(),
                                        onOpen: () => _open(docs[i].data()),
                                        onToggleSave: () => _remove(docs[i]),
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  void _open(Map<String, dynamic> data) {
    final image = (data['images'] is List && data['images'].isNotEmpty)
        ? data['images'][0]
        : data['imageUrl'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TenantPropertyDetail(
          propertyId: data['id']?.toString(),
          price: data['price']?.toString(),
          location: data['address'] ?? data['location'],
          imagePath: image,
          propertyData: data,
        ),
      ),
    );
  }

  Future<void> _remove(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      await Api.removeSavedProperty(
          tenantEmail: _user!.email!, propertyId: doc['id']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _ViewToggle extends StatelessWidget {
  final bool grid;
  final bool selected;
  final VoidCallback onTap;
  const _ViewToggle(
      {required this.grid, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? AppConfig.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(grid ? Icons.grid_view : Icons.view_list,
            size: 20, color: selected ? Colors.white : Colors.black87),
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  final VoidCallback onToggleSave;
  const _SavedCard(
      {required this.data, required this.onOpen, required this.onToggleSave});

  // Ratings removed

  @override
  Widget build(BuildContext context) {
    final image = (data['images'] is List && data['images'].isNotEmpty)
        ? data['images'][0]
        : data['imageUrl'] ?? '';
    final title = data['title']?.toString() ?? 'Property';
    final price = data['price']?.toString() ?? '';
    final city = data['city']?.toString();
    final address = data['address']?.toString();
    final location = [address, city]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(', ');
    // Ratings removed
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: image.isNotEmpty
                          ? Image.network(image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image),
                                  ))
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onToggleSave,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Icon(Icons.favorite,
                              size: 18, color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("₹ $price",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 6),
                  // Ratings removed
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SavedListTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  final VoidCallback onToggleSave;
  const _SavedListTile(
      {required this.data, required this.onOpen, required this.onToggleSave});

  // Ratings removed

  @override
  Widget build(BuildContext context) {
    final image = (data['images'] is List && data['images'].isNotEmpty)
        ? data['images'][0]
        : data['imageUrl'] ?? '';
    final title = data['title']?.toString() ?? 'Property';
    final price = data['price']?.toString() ?? '';
    final city = data['city']?.toString();
    final address = data['address']?.toString();
    final location = [address, city]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(', ');
    // Ratings removed
    return InkWell(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 130,
                height: 120,
                child: Stack(children: [
                  Positioned.fill(
                    child: image.isNotEmpty
                        ? Image.network(image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image),
                                ))
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onToggleSave,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(Icons.favorite,
                            size: 18, color: Colors.redAccent),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text("₹ $price",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 10),
                    // Ratings removed
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
