import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vaccine/app_colors.dart';
import 'package:vaccine/booking_screen.dart';
import 'package:vaccine/history_screen.dart';
import 'package:vaccine/login_screen.dart';
import 'package:image_picker/image_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _profileData;
  String? _localAvatarPath;
  final GlobalKey<HistoryScreenState> historyKey = GlobalKey<HistoryScreenState>();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _profileData = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void refreshData() {
    _fetchProfile();
    historyKey.currentState?.refreshData();
    setState(() {});
  }

  void setTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildAvatarWidget(double size) {
    if (_localAvatarPath != null) {
      return Image.file(
        File(_localAvatarPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppColors.primary),
      );
    }
    final avatarUrl = _profileData?['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppColors.primary),
      );
    }
    return Icon(Icons.person, size: size * 0.6, color: AppColors.primary);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _VaccinePage(),
      HistoryScreen(key: historyKey),
      _ProfilePage(
        profileData: _profileData,
        localAvatarPath: _localAvatarPath,
        onLogout: _handleLogout,
        onProfileUpdated: (newData) {
          setState(() {
            _profileData = newData;
          });
        },
        onLocalAvatarChanged: (path) {
          setState(() {
            _localAvatarPath = path;
          });
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.95),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.outlineVariant.withValues(alpha: 0.3), height: 1),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: ClipOval(
                child: _buildAvatarWidget(32),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'VaxCare',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.onSurfaceVariant),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bạn không có thông báo mới nào.'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Cá nhân'),
          ],
        ),
      ),
    );
  }
}

// ─── Format price helper ──────────────────────────────────────────────────────
String _formatPrice(dynamic raw) {
  if (raw == null) return '0 VNĐ';
  double? dVal;
  if (raw is num) {
    dVal = raw.toDouble();
  } else {
    dVal = double.tryParse(raw.toString());
  }
  final value = dVal?.toInt() ?? 0;
  final str = value.toString();
  final buf = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buf.write('.');
    buf.write(str[i]);
    count++;
  }
  return '${buf.toString().split('').reversed.join()} VNĐ';
}

// ─── Tab 1: Trang chủ vắc-xin ────────────────────────────────────────────────
class _VaccinePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 80),
      children: [
        // Hero banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tìm kiếm Vắc-xin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onPrimary)),
                  const SizedBox(height: 4),
                  Text('Bảo vệ sức khỏe cho bạn và gia đình', style: TextStyle(fontSize: 14, color: AppColors.onPrimary.withValues(alpha: 0.9))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Tên vắc-xin, bệnh ngăn ngừa...',
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: AppColors.outline),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: -30,
                bottom: -30,
                child: Transform.rotate(
                  angle: 0.2,
                  child: Icon(Icons.vaccines, size: 140, color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Vaccine cards
        FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client.from('vaccines').select('*'),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return Center(child: Text('Lỗi: ${snap.error}'));
            }
            final vaccines = snap.data ?? [];
            if (vaccines.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Chưa có vắc-xin nào.', style: TextStyle(color: Colors.grey))));
            }
            return Column(
              children: vaccines.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _VaccineCard(vaccineData: v),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _VaccineCard extends StatelessWidget {
  final Map<String, dynamic> vaccineData;
  const _VaccineCard({required this.vaccineData});

  void _navigateToBooking(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingScreen(vaccineData: vaccineData)),
    );
    if (result == true && context.mounted) {
      final homeState = context.findAncestorStateOfType<_HomeScreenState>();
      homeState?.refreshData();
      homeState?.setTab(1); // Switch to History tab
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = vaccineData['name'] ?? 'Chưa rõ';
    final origin = vaccineData['origin'] ?? vaccineData['country'] ?? 'Chưa rõ';
    final description = vaccineData['description'] ?? 'Chưa có mô tả chi tiết cho loại vắc-xin này.';
    final price = _formatPrice(vaccineData['price']);

    return InkWell(
      onTap: () => _navigateToBooking(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: AppColors.secondary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.public, size: 14, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                origin,
                                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                price,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _navigateToBooking(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Đặt lịch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Tab 3: Cá nhân ──────────────────────────────────────────────────────────
// ─── Tab 3: Cá nhân ──────────────────────────────────────────────────────────
class _ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String? localAvatarPath;
  final VoidCallback onLogout;
  final Function(Map<String, dynamic>) onProfileUpdated;
  final Function(String) onLocalAvatarChanged;

  const _ProfilePage({
    super.key,
    required this.profileData,
    required this.localAvatarPath,
    required this.onLogout,
    required this.onProfileUpdated,
    required this.onLocalAvatarChanged,
  });

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool _isSaving = false;

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      // Update local preview immediately
      widget.onLocalAvatarChanged(image.path);

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      setState(() { _isSaving = true; });

      final fileBytes = await image.readAsBytes();
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 1. Upload to Supabase Storage
      try {
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(fileName, fileBytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));

        // 2. Get Public URL
        final publicUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);

        // 3. Update profiles table
        final updatedData = await Supabase.instance.client
            .from('profiles')
            .update({'avatar_url': publicUrl})
            .eq('id', user.id)
            .select()
            .single();

        widget.onProfileUpdated(updatedData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật ảnh đại diện thành công!'), backgroundColor: Colors.green),
          );
        }
      } catch (storageError) {
        // Fallback: update avatar_url inside profile fails or storage fails
        debugPrint('Storage/DB error: $storageError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lưu ý: Không thể đồng bộ ảnh lên Supabase (Cần tạo bucket "avatars" và cột "avatar_url"). Ảnh hiện hiển thị tạm thời.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: widget.profileData?['full_name'] ?? '');
    final phoneController = TextEditingController(text: widget.profileData?['phone_number'] ?? '');
    final user = Supabase.instance.client.auth.currentUser;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Sửa thông tin cá nhân', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: AppColors.onSurfaceVariant)),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Họ tên và SĐT không được để trống!'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    setDialogState(() { _isSaving = true; });
                    try {
                      if (user != null) {
                        final updatedData = await Supabase.instance.client
                            .from('profiles')
                            .update({
                              'full_name': nameController.text.trim(),
                              'phone_number': phoneController.text.trim(),
                            })
                            .eq('id', user.id)
                            .select()
                            .single();
                        
                        widget.onProfileUpdated(updatedData);
                      }
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cập nhật thông tin thành công!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setDialogState(() { _isSaving = false; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.profileData?['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? 'Chưa đăng nhập';
    final name = widget.profileData?['full_name'] ?? 'Chưa cập nhật';
    final phone = widget.profileData?['phone_number'] ?? 'Chưa cập nhật';
    final dob = widget.profileData?['date_of_birth'] ?? 'Chưa cập nhật';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        // Avatar
        Center(
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: _buildAvatar(100),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    onPressed: _changeAvatar,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Info container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              _ProfileRow(
                icon: Icons.person_outline,
                label: 'Họ và tên',
                value: name,
                onEdit: _showEditDialog,
              ),
              const Divider(height: 24),
              _ProfileRow(
                icon: Icons.phone_outlined,
                label: 'Số điện thoại',
                value: phone,
                onEdit: _showEditDialog,
              ),
              const Divider(height: 24),
              _ProfileRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
              ),
              const Divider(height: 24),
              _ProfileRow(
                icon: Icons.cake_outlined,
                label: 'Ngày sinh',
                value: dob,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(double size) {
    if (widget.localAvatarPath != null) {
      return Image.file(
        File(widget.localAvatarPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: AppColors.primary),
      );
    }
    final avatarUrl = widget.profileData?['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: AppColors.primary),
      );
    }
    return const Icon(Icons.person, size: 50, color: AppColors.primary);
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;
  const _ProfileRow({required this.icon, required this.label, required this.value, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
            onPressed: onEdit,
          ),
      ],
    );
  }
}