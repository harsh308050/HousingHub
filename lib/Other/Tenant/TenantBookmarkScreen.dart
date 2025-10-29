import 'package:flutter/material.dart';
import 'package:housinghub/Helper/Models.dart';
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

  // Validate saved properties to filter out deleted ones
  Future<List<Map<String, dynamic>>> _validateSavedProperties(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    List<Map<String, dynamic>> validProperties = [];

    for (var doc in docs) {
      try {
        final data = doc.data();
        final propertyId = data['id'] ?? doc.id;
        final ownerEmail = data['ownerEmail'] as String?;

        // Skip if no owner email
        if (ownerEmail == null || ownerEmail.isEmpty) {
          print('Skipping saved property $propertyId - no owner email');
          continue;
        }

        // Check if property still exists in Firestore
        final propertyExists =
            await Api.getPropertyById(ownerEmail, propertyId);

        if (propertyExists != null) {
          // Property still exists, add to valid list
          validProperties.add(data);
        } else {
          print(
              'Saved property $propertyId by $ownerEmail has been deleted - removing from saved properties');
          // Remove from saved properties collection
          _removeDeletedPropertyFromSaved(doc.reference);
        }
      } catch (e) {
        print('Error validating saved property: $e');
        // On error, skip this property
        continue;
      }
    }

    return validProperties;
  }

  // Remove deleted property from tenant's saved properties
  Future<void> _removeDeletedPropertyFromSaved(
      DocumentReference docRef) async {
    try {
      await docRef.delete();
      print('Removed deleted property from saved properties');
    } catch (e) {
      print('Error removing deleted property from saved properties: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user?.email == null) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text(
            'Saved Listings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
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

        // Validate properties exist before displaying
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: waiting ? null : _validateSavedProperties(docs),
          builder: (context, validationSnapshot) {
            final validProperties = validationSnapshot.data ?? [];
            final isValidating =
                !waiting && validationSnapshot.connectionState == ConnectionState.waiting;

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                elevation: 0,
                centerTitle: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                title: const Text('Saved Listings',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
                leading: Navigator.canPop(context)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
              ),
              body: waiting || isValidating
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
                                  Text('${validProperties.length} saved listings',
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
                              if (validProperties.isEmpty)
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
                                          itemCount: validProperties.length,
                                          itemBuilder: (c, i) => _SavedCard(
                                            data: validProperties[i],
                                            onOpen: () => _open(validProperties[i]),
                                            onToggleSave: () => _removeValidated(validProperties[i]),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding:
                                              const EdgeInsets.only(bottom: 16),
                                          itemCount: validProperties.length,
                                          itemBuilder: (c, i) => _SavedListTile(
                                            data: validProperties[i],
                                            onOpen: () => _open(validProperties[i]),
                                            onToggleSave: () => _removeValidated(validProperties[i]),
                                          ),
                                        ),
                                ),
                            ],
                          ),
                        ),
            );
          },
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

  Future<void> _removeValidated(Map<String, dynamic> data) async {
    final tenantEmail = _user?.email;
    if (tenantEmail == null) return;

    final propertyId = data['id']?.toString();
    if (propertyId == null || propertyId.isEmpty) return;

    try {
      await Api.removeSavedProperty(
          tenantEmail: tenantEmail, propertyId: propertyId);
    } catch (e) {
      if (!mounted) return;
      Models.showErrorSnackBar(context, 'Error removing property: $e');
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

  String _getFormattedPrice() {
    final listingType = data['listingType'] ?? 'rent';
    
    if (listingType == 'sale') {
      final salePrice = data['salePrice'] ?? data['price'] ?? '';
      if (salePrice.toString().isEmpty) return '';
      String priceValue = salePrice.toString().replaceAll('₹', '').replaceAll(',', '').trim();
      return Models.formatIndianCurrency(priceValue);
    } else {
      final rentPrice = data['price'] ?? '';
      if (rentPrice.toString().isEmpty) return '';
      String priceValue = rentPrice.toString().replaceAll('₹', '').replaceAll('/month', '').replaceAll(',', '').trim();
      return Models.formatIndianCurrency(priceValue);
    }
  }

  // Ratings removed

  @override
  Widget build(BuildContext context) {
    final image = (data['images'] is List && data['images'].isNotEmpty)
        ? data['images'][0]
        : data['imageUrl'] ?? '';
    final title = data['title']?.toString() ?? 'Property';
    final formattedPrice = _getFormattedPrice();
    final city = data['city']?.toString();
    final address = data['address']?.toString();
    final location = [address, city]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(', ');
    final listingType = data['listingType'] ?? 'rent';
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
                  Text(formattedPrice.isNotEmpty 
                      ? "₹$formattedPrice${listingType == 'rent' ? '/month' : ''}"
                      : "Price not available",
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

  String _getFormattedPrice() {
    final listingType = data['listingType'] ?? 'rent';
    
    if (listingType == 'sale') {
      final salePrice = data['salePrice'] ?? data['price'] ?? '';
      if (salePrice.toString().isEmpty) return '';
      String priceValue = salePrice.toString().replaceAll('₹', '').replaceAll(',', '').trim();
      return Models.formatIndianCurrency(priceValue);
    } else {
      final rentPrice = data['price'] ?? '';
      if (rentPrice.toString().isEmpty) return '';
      String priceValue = rentPrice.toString().replaceAll('₹', '').replaceAll('/month', '').replaceAll(',', '').trim();
      return Models.formatIndianCurrency(priceValue);
    }
  }

  // Ratings removed

  @override
  Widget build(BuildContext context) {
    final image = (data['images'] is List && data['images'].isNotEmpty)
        ? data['images'][0]
        : data['imageUrl'] ?? '';
    final title = data['title']?.toString() ?? 'Property';
    final formattedPrice = _getFormattedPrice();
    final city = data['city']?.toString();
    final address = data['address']?.toString();
    final location = [address, city]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(', ');
    final listingType = data['listingType'] ?? 'rent';
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
                    Text(formattedPrice.isNotEmpty 
                        ? "₹$formattedPrice${listingType == 'rent' ? '/month' : ''}"
                        : "Price not available",
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
