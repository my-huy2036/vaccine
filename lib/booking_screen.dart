import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vaccine/app_colors.dart';
import 'package:vaccine/services/notification_service.dart';
import 'package:vaccine/services/vietqr_service.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> vaccineData;

  const BookingScreen({
    super.key,
    required this.vaccineData,
  });

  String get vaccineName => vaccineData['name'] ?? 'Không rõ';
  int get price {
    final raw = vaccineData['price'];
    if (raw == null) return 0;
    if (raw is num) {
      return raw.toInt();
    }
    final parsedDouble = double.tryParse(raw.toString());
    return parsedDouble?.toInt() ?? 0;
  }

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  bool isConfirming = false;
  bool isConfirmed = false;
  String? _qrBase64; // base64 data URL từ VietQR API
  bool _qrLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQR();
  }

  Future<void> _loadQR() async {
    final addInfo = _buildAddInfo();
    final result = await VietQRService.generateQR(
      amount: widget.price,
      addInfo: addInfo,
    );
    if (mounted) {
      setState(() {
        _qrBase64 = result;
        _qrLoading = false;
      });
    }
  }

  String _buildAddInfo() {
    final unsignedName = _toUnsigned(widget.vaccineName).replaceAll(' ', '');
    return 'VAXCARE $unsignedName';
  }

  static final _vnMap = <String, String>{
    'á':'a','à':'a','ả':'a','ã':'a','ạ':'a',
    'â':'a','ấ':'a','ầ':'a','ẩ':'a','ẫ':'a','ậ':'a',
    'ă':'a','ắ':'a','ằ':'a','ẳ':'a','ẵ':'a','ặ':'a',
    'é':'e','è':'e','ẻ':'e','ẽ':'e','ẹ':'e',
    'ê':'e','ế':'e','ề':'e','ể':'e','ễ':'e','ệ':'e',
    'í':'i','ì':'i','ỉ':'i','ĩ':'i','ị':'i',
    'ó':'o','ò':'o','ỏ':'o','õ':'o','ọ':'o',
    'ô':'o','ố':'o','ồ':'o','ổ':'o','ỗ':'o','ộ':'o',
    'ơ':'o','ớ':'o','ờ':'o','ở':'o','ỡ':'o','ợ':'o',
    'ú':'u','ù':'u','ủ':'u','ũ':'u','ụ':'u',
    'ư':'u','ứ':'u','ừ':'u','ử':'u','ữ':'u','ự':'u',
    'ý':'y','ỳ':'y','ỷ':'y','ỹ':'y','ỵ':'y',
    'đ':'d',
  };

  String _toUnsigned(String src) {
    final buf = StringBuffer();
    for (final ch in src.toLowerCase().characters) {
      buf.write(_vnMap[ch] ?? ch);
    }
    String result = buf.toString();
    // Chỉ giữ lại a-z, 0-9, và khoảng trắng
    result = result.replaceAll(RegExp('[^a-z0-9 ]'), '');
    // Gộp nhiều khoảng trắng liên tiếp thành một
    result = result.replaceAll(RegExp(' +'), ' ');
    return result.trim().toUpperCase();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _handleConfirm() async {
    if (isConfirming || isConfirmed) return;

    setState(() {
      isConfirming = true;
    });

    final String addInfo = _buildAddInfo();
    final int price = widget.price;
    final String displayPrice = '${price.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")} VNĐ';

    try {
      // 1. Kiểm tra trạng thái thanh toán từ VietQR Merchant API
      final bool isPaid = await VietQRService.checkPaymentStatus(
        addInfo: addInfo,
        amount: price,
      );

      if (!isPaid) {
        if (mounted) {
          setState(() {
            isConfirming = false;
          });
          
          // Hiển thị hộp thoại thông báo chưa nhận được thanh toán cực kỳ chuyên nghiệp
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppColors.surfaceContainerLowest,
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Chờ thanh toán',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hệ thống chưa ghi nhận được giao dịch chuyển khoản từ tài khoản của bạn.',
                    style: TextStyle(fontSize: 14, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Số tiền: $displayPrice', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('• Nội dung chuyển khoản: $addInfo', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lưu ý: Nếu bạn vừa thực hiện chuyển khoản thành công, vui lòng chờ ngân hàng xử lý trong 1-2 phút rồi nhấn nút "Kiểm tra lại".',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.outline),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng', style: TextStyle(color: AppColors.onSurfaceVariant)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleConfirm(); // Thử kiểm tra lại
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kiểm tra lại'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 2. Lưu vào Supabase khi thanh toán thành công
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final List<dynamic> response = await Supabase.instance.client.from('appointments').insert({
          'user_id': user.id,
          'vaccine_id': widget.vaccineData['id'],
          'appointment_date': selectedDate.toIso8601String(),
          'status': 'confirmed',
        }).select();

        if (response.isNotEmpty) {
          final String appointmentId = response.first['id'].toString();
          try {
            await NotificationService().scheduleVaccinationReminders(
              appointmentId: appointmentId,
              vaccineName: widget.vaccineName,
              appointmentDate: selectedDate,
            );
          } catch (notifError) {
            debugPrint('Lỗi đặt lịch thông báo: $notifError');
          }
        }
      } else {
        // Giả lập lưu thành công khi test mà không cần đăng nhập
        await Future.delayed(const Duration(seconds: 1));
      }
      
      if (mounted) {
        setState(() {
          isConfirming = false;
          isConfirmed = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác nhận thanh toán thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isConfirming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    
    final int price = widget.price;
    final String addInfo = _buildAddInfo();
    final String fallbackUrl = VietQRService.getFallbackImageUrl(
      amount: price,
      addInfo: addInfo,
    );
    
    // Format price to display like "850.000 VNĐ"
    final String displayPrice = '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VNĐ';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Đặt lịch tiêm',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceVariant),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.outlineVariant.withOpacity(0.5),
            height: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 120),
            children: [
              // Date Selection Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn ngày hẹn tiêm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer.withOpacity(0.5),
                          border: Border.all(color: AppColors.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.outline),
                        SizedBox(width: 4),
                        Text(
                          'Vui lòng chọn ngày còn trống lịch trong tuần.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Thanh toán dịch vụ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Quét mã QR dưới đây để hoàn tất đặt lịch',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // QR Container
                    Container(
                      width: 240,
                      height: 240,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Color(0xFFF1F5F9)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                      ),
                      child: Center(
                        child: _qrLoading
                            ? const CircularProgressIndicator()
                            : _qrBase64 != null
                                ? Image.memory(
                                    base64Decode(_qrBase64!.split(',').last),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Image.network(
                                          fallbackUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.error_outline, color: AppColors.error),
                                        ),
                                  )
                                : Image.network(
                                    fallbackUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const CircularProgressIndicator();
                                    },
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.error_outline, color: AppColors.error),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Payment details
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Số tiền',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              displayPrice,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 16, color: AppColors.outlineVariant),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Nội dung',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              addInfo,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Status Tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: AppColors.primary, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hệ thống sẽ tự động xác nhận sau 2-5 phút khi giao dịch hoàn tất. Vui lòng không đóng màn hình này.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Fixed Bottom Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.9),
                border: Border(
                  top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                ),
              ),
              child: ElevatedButton(
                onPressed: _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConfirmed ? AppColors.secondary : (isConfirming ? AppColors.primaryContainer : AppColors.primary),
                  foregroundColor: isConfirmed ? AppColors.onSecondary : (isConfirming ? AppColors.onPrimaryContainer : AppColors.onPrimary),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: isConfirming || isConfirmed ? 0 : 4,
                  shadowColor: AppColors.primary.withOpacity(0.5),
                ),
                child: isConfirming
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Đang kiểm tra...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isConfirmed ? 'Thanh toán thành công' : 'Xác nhận đã chuyển khoản',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isConfirmed ? Icons.verified : Icons.check_circle,
                            size: 24,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}