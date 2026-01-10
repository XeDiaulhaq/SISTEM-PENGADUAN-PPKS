import 'package:flutter_test/flutter_test.dart';

import 'package:sistem_pengaduan_ppks/services/auth_service.dart';
import 'package:sistem_pengaduan_ppks/services/report_service.dart';

void main() {
  test('admin login and fetch reports via FastAPI backend', () async {
    final authService = AuthService();
    final reportService = ReportService();

    final loginResponse = await authService.login('admin', 'admin123');
    expect(loginResponse.accessToken, isNotEmpty);

    final reports = await reportService.fetchReports(loginResponse.accessToken);
    expect(reports, isA<List>());
  }, timeout: const Timeout(Duration(seconds: 10)));
}
