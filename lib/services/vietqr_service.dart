import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class VietQRService {
  // ═══════════════════════════════════════════════════════════════════════════
  // CẤU HÌNH - THAY ĐỔI THÔNG TIN CỦA BẠN TẠI ĐÂY
  // ═══════════════════════════════════════════════════════════════════════════

  // 1. Đăng ký tại https://my.vietqr.io/ để lấy clientId và apiKey (Cho mã QR)
  static const String clientId = '57bb94df-7d35-49ef-980e-ea9cfe5622d6';  // <-- Client ID của bạn
  static const String apiKey = '68721703-6ac7-4cb2-93ac-730ea67819e8';    // <-- API Key của bạn

  // 2. Đăng ký tại https://vietqr.vn/merchant/request để lấy Username & Password (Để check giao dịch)
  // Nếu để trống, ứng dụng sẽ chạy ở chế độ giả lập (Simulator) để test luồng mượt mà.
  static const String vietQrUsername = ''; // <-- Điền Username VietQR Merchant của bạn
  static const String vietQrPassword = ''; // <-- Điền Password VietQR Merchant của bạn

  // 3. Thông tin tài khoản ngân hàng nhận tiền:
  static const String accountNo = '0947776209';
  static const String accountName = 'NGUYEN NGOC QUANG HUY'; // Tên chủ TK, viết HOA không dấu
  static const int acqId = 970422;    // BIN ngân hàng MB Bank
  static const String bankCode = 'MB'; // Mã ngân hàng (dùng cho fallback URL)
  static const String template = 'compact2';

  // Cấu hình máy chủ VietQR Merchant API
  // Môi trường Sandbox: 'https://dev.vietqr.org'
  // Môi trường Production: 'https://api.vietqr.org'
  static const String vietQrHost = 'https://api.vietqr.org';

  // ═══════════════════════════════════════════════════════════════════════════

  /// Kiểm tra xem đã cấu hình API key hay chưa
  static bool get hasApiKey => clientId.isNotEmpty && apiKey.isNotEmpty;

  /// Kiểm tra xem đã cấu hình Merchant API để check thanh toán thật hay chưa
  static bool get hasMerchantConfig => vietQrUsername.isNotEmpty && vietQrPassword.isNotEmpty;

  /// Sinh mã QR qua VietQR POST API (trả về base64 image data)
  /// Trả về null nếu lỗi
  static Future<String?> generateQR({
    required int amount,
    required String addInfo,
  }) async {
    if (!hasApiKey) {
      debugPrint('[VietQR] Chưa cấu hình API key, dùng fallback URL image.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.vietqr.io/v2/generate'),
        headers: {
          'x-client-id': clientId,
          'x-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'accountNo': accountNo,
          'accountName': accountName,
          'acqId': acqId,
          'amount': amount,
          'addInfo': addInfo.length > 25 ? addInfo.substring(0, 25) : addInfo,
          'template': template,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == '00' && data['data'] != null) {
          final qrDataURL = data['data']['qrDataURL'] as String?;
          return qrDataURL; // data:image/png;base64,...
        }
        debugPrint('[VietQR] API trả về code: ${data['code']} - ${data['desc']}');
      } else {
        debugPrint('[VietQR] HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[VietQR] Lỗi gọi API: $e');
    }
    return null;
  }

  /// Fallback: Trả về URL image trực tiếp (không cần API key)
  static String getFallbackImageUrl({
    required int amount,
    required String addInfo,
  }) {
    final safeAddInfo = addInfo.length > 25 ? addInfo.substring(0, 25) : addInfo;
    return 'https://img.vietqr.io/image/$bankCode-$accountNo-$template.png'
        '?amount=$amount'
        '&addInfo=${Uri.encodeComponent(safeAddInfo)}';
  }

  /// Kiểm tra trạng thái thanh toán từ VietQR Merchant API
  /// Trả về true nếu đã thanh toán thành công, false nếu chưa hoặc lỗi.
  static Future<bool> checkPaymentStatus({
    required String addInfo,
    required int amount,
  }) async {
    final safeAddInfo = addInfo.length > 25 ? addInfo.substring(0, 25) : addInfo;

    if (!hasMerchantConfig) {
      // ═══════════════════════════════════════════════════════════════════════
      // CHẾ ĐỘ GIẢ LẬP (SIMULATOR MODE)
      // ═══════════════════════════════════════════════════════════════════════
      debugPrint('[VietQR] Chưa cấu hình Merchant API (Username/Password), chạy giả lập check thanh toán.');
      await Future.delayed(const Duration(milliseconds: 1800)); // Giả lập độ trễ kết nối ngân hàng
      return true; // Luôn giả lập thành công để người dùng kiểm thử quy trình mượt mà
    }

    try {
      // Bước 1: Lấy Bearer Token bằng Basic Authentication
      final String basicAuth = 'Basic ' + base64Encode(utf8.encode('$vietQrUsername:$vietQrPassword'));
      
      final tokenResponse = await http.post(
        Uri.parse('$vietQrHost/vqr/api/token_generate'),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
        },
      );

      if (tokenResponse.statusCode != 200) {
        debugPrint('[VietQR Merchant] Lấy Token thất bại: ${tokenResponse.statusCode}');
        return false;
      }

      final tokenData = jsonDecode(tokenResponse.body);
      final String? accessToken = tokenData['access_token'];
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[VietQR Merchant] Access Token rỗng');
        return false;
      }

      // Bước 2: Tạo md5 checkSum = md5(bankAccount + username)
      final String toHash = '$accountNo$vietQrUsername';
      final String checkSum = md5.convert(utf8.encode(toHash)).toString();

      // Bước 3: Gọi API check-order để kiểm tra giao dịch
      final checkResponse = await http.post(
        Uri.parse('$vietQrHost/vqr/api/transactions/check-order'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bankAccount': accountNo,
          'type': '1', // 1: Kiểm tra theo referenceNumber / nội dung addInfo
          'value': safeAddInfo,
          'checkSum': checkSum,
        }),
      );

      if (checkResponse.statusCode == 200) {
        final checkData = jsonDecode(checkResponse.body);
        // Trạng thái: 1 = Đã thanh toán thành công, 0 = Đang chờ, 2 = Hết hạn
        final status = checkData['status'];
        debugPrint('[VietQR Merchant] Kết quả check giao dịch: status = $status');
        return status == 1;
      } else {
        debugPrint('[VietQR Merchant] Gọi API check-order lỗi: ${checkResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('[VietQR Merchant] Lỗi xử lý kiểm tra giao dịch: $e');
    }
    return false;
  }
}
