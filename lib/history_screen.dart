import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vaccine/app_colors.dart';
import 'package:vaccine/services/notification_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  // 0 = Tất cả, 1 = Đã hoàn thành, 2 = Đã hủy
  int _filterIndex = 0;
  Future<List<Map<String, dynamic>>>? _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  void refreshData() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    setState(() {
      _appointmentsFuture = userId.isEmpty
          ? Future.value([])
          : Supabase.instance.client
              .from('appointments')
              .select('*, vaccines(*)')
              .eq('user_id', userId)
              .order('appointment_date', ascending: false);
    });
  }

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

  void _showCancelDialog(String appointmentId) {
    String selectedReason = 'Bận việc đột xuất';
    bool isCancelling = false;
    final List<String> reasons = [
      'Bận việc đột xuất',
      'Sức khỏe không đảm bảo',
      'Thay đổi kế hoạch tiêm',
      'Đã tiêm chủng tại nơi khác',
      'Lý do khác',
    ];

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing while cancelling
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text(
                'Hủy lịch hẹn tiêm',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bạn có chắc chắn muốn hủy lịch hẹn này không? Vui lòng chọn lý do hủy:',
                    style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedReason,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: reasons.map((String reason) {
                          return DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: isCancelling ? null : (String? newValue) {
                          if (newValue != null) {
                            setDialogState(() {
                              selectedReason = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isCancelling ? null : () => Navigator.pop(context),
                  child: const Text('Đóng', style: TextStyle(color: AppColors.onSurfaceVariant)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isCancelling ? null : () async {
                    setDialogState(() { isCancelling = true; });
                    
                    final scaffold = ScaffoldMessenger.of(context);

                    try {
                      await Supabase.instance.client
                          .from('appointments')
                          .update({
                            'status': 'cancelled',
                            'cancel_reason': selectedReason,
                          })
                          .eq('id', appointmentId);
                      
                      try {
                        await NotificationService().cancelNotifications(appointmentId);
                      } catch (err) {
                        debugPrint('Lỗi gỡ lịch thông báo: $err');
                      }
                      
                      if (context.mounted) Navigator.pop(context);
                      scaffold.showSnackBar(
                        const SnackBar(
                          content: Text('Đã hủy lịch hẹn thành công!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      refreshData();
                    } catch (e) {
                      try {
                        await Supabase.instance.client
                            .from('appointments')
                            .update({
                              'status': 'cancelled',
                            })
                            .eq('id', appointmentId);

                        try {
                          await NotificationService().cancelNotifications(appointmentId);
                        } catch (err) {
                          debugPrint('Lỗi gỡ lịch thông báo: $err');
                        }

                        if (context.mounted) Navigator.pop(context);
                        scaffold.showSnackBar(
                          const SnackBar(
                            content: Text('Đã hủy lịch hẹn! Cảnh báo: Cột "cancel_reason" chưa có trên Supabase.'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 5),
                          ),
                        );
                        refreshData();
                      } catch (err) {
                        setDialogState(() { isCancelling = false; });
                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text('Lỗi khi hủy: $err'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: isCancelling 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Xác nhận hủy'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _matchesFilter(String status) {
    if (_filterIndex == 0) return true;
    if (_filterIndex == 1) return status == 'confirmed' || status == 'pending';
    if (_filterIndex == 2) return status == 'completed';
    if (_filterIndex == 3) return status == 'cancelled';
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _appointmentsFuture,
      builder: (context, snapshot) {
        final allItems = List<Map<String, dynamic>>.from(snapshot.data ?? []);

        // In-memory sorting (descending by appointment_date)
        allItems.sort((a, b) {
          final aDateStr = a['appointment_date'] ?? '';
          final bDateStr = b['appointment_date'] ?? '';
          if (aDateStr.isEmpty) return 1;
          if (bDateStr.isEmpty) return -1;
          try {
            final aDate = DateTime.parse(aDateStr);
            final bDate = DateTime.parse(bDateStr);
            return bDate.compareTo(aDate);
          } catch (_) {
            return 0;
          }
        });

        final filteredItems = allItems.where((a) => _matchesFilter(a['status'] ?? '')).toList();

        return ListView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
          children: [
            // Header
            const Text(
              'Lịch sử tiêm chủng',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 4),
            const Text(
              'Theo dõi các đợt tiêm chủng đã thực hiện',
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),



            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _FilterChip(label: 'Tất cả', isSelected: _filterIndex == 0, onTap: () => setState(() => _filterIndex = 0)),
                  _FilterChip(label: 'Lịch sắp tới', isSelected: _filterIndex == 1, onTap: () => setState(() => _filterIndex = 1)),
                  _FilterChip(label: 'Đã hoàn thành', isSelected: _filterIndex == 2, onTap: () => setState(() => _filterIndex = 2)),
                  _FilterChip(label: 'Đã hủy', isSelected: _filterIndex == 3, onTap: () => setState(() => _filterIndex = 3)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),

            // Error state
            if (snapshot.hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                ),
              ),

            // Empty state
            if (snapshot.connectionState != ConnectionState.waiting && !snapshot.hasError && filteredItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                        child: const Icon(Icons.vaccines_outlined, color: AppColors.outline, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filterIndex == 0 ? 'Chưa từng tiêm vắc-xin' : 'Không có kết quả phù hợp',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Hãy đặt lịch tiêm ngay hôm nay!',
                        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),

             // History list
            if (snapshot.connectionState != ConnectionState.waiting && filteredItems.isNotEmpty)
              ...filteredItems.map((a) {
                final vaccine = a['vaccines'] as Map<String, dynamic>? ?? {};
                final title = vaccine['name'] ?? a['vaccine_name'] ?? 'Không rõ';
                final priceVal = vaccine['price'] ?? a['price'];
                final statusRaw = a['status'] ?? 'unknown';
                final cancelReason = a['cancel_reason'] as String?;

                String statusDisplay = 'Chưa rõ';
                if (statusRaw == 'completed') {
                  statusDisplay = 'Đã hoàn thành';
                } else if (statusRaw == 'confirmed') {
                  statusDisplay = 'Đã xác nhận';
                } else if (statusRaw == 'pending') {
                  statusDisplay = 'Đang chờ';
                } else if (statusRaw == 'cancelled') {
                  statusDisplay = 'Đã hủy';
                }

                String dateStr = a['appointment_date'] ?? '';
                if (dateStr.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(dateStr);
                    dateStr = '${dt.day} Tháng ${dt.month}, ${dt.year}';
                  } catch (_) {}
                }

                final isCancellable = statusRaw == 'confirmed' || statusRaw == 'pending';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HistoryItem(
                    title: title,
                    status: statusDisplay,
                    date: dateStr,
                    location: 'Trung tâm Tiêm chủng VaxCare',
                    price: _formatPrice(priceVal),
                    statusRaw: statusRaw,
                    cancelReason: cancelReason,
                    onTap: isCancellable ? () => _showCancelDialog(a['id'].toString()) : null,
                  ),
                );
              }),

            // Footer (chỉ hiện khi có data)
            if (snapshot.connectionState != ConnectionState.waiting && filteredItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                        child: const Icon(Icons.history_toggle_off, color: AppColors.outline, size: 24),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bạn đã xem hết lịch sử tiêm',
                        style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── History Item Card ────────────────────────────────────────────────────────
class _HistoryItem extends StatelessWidget {
  final String title;
  final String status;
  final String date;
  final String location;
  final String price;
  final String statusRaw;
  final String? cancelReason;
  final VoidCallback? onTap;

  const _HistoryItem({
    required this.title,
    required this.status,
    required this.date,
    required this.location,
    required this.price,
    required this.statusRaw,
    this.cancelReason,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasCancelReason = cancelReason != null && cancelReason!.isNotEmpty;
    final isCancelled = statusRaw == 'cancelled';

    Color barColor;
    Color badgeBg;
    Color badgeTextColor;

    if (statusRaw == 'completed') {
      barColor = AppColors.secondary;
      badgeBg = AppColors.secondaryContainer;
      badgeTextColor = AppColors.onSecondaryContainer;
    } else if (statusRaw == 'confirmed' || statusRaw == 'pending') {
      barColor = AppColors.primary;
      badgeBg = AppColors.primaryFixed;
      badgeTextColor = AppColors.primary;
    } else {
      // cancelled or other
      barColor = AppColors.outline.withValues(alpha: 0.5);
      badgeBg = AppColors.errorContainer;
      badgeTextColor = AppColors.onErrorContainer;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCancelled
              ? AppColors.surfaceContainerLowest.withValues(alpha: 0.6)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCancelled
                ? AppColors.outlineVariant.withValues(alpha: 0.2)
                : AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left color bar
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Opacity(
                  opacity: isCancelled ? 0.75 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isCancelled ? AppColors.onSurfaceVariant : AppColors.primary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                              decoration: isCancelled ? TextDecoration.lineThrough : TextDecoration.none,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            price,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isCancelled ? Icons.block : Icons.location_on,
                            size: 16,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                                fontStyle: isCancelled ? FontStyle.italic : FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (hasCancelReason) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Lý do hủy: $cancelReason',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Chevron
              if (onTap != null)
                const Center(child: Icon(Icons.chevron_right, color: AppColors.outline)),
            ],
          ),
        ),
      ),
    );
  }
}