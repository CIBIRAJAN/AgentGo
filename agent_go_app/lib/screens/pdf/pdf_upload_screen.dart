import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import 'due_pdf_upload_tab.dart';
import 'commission_pdf_upload_tab.dart';

/// Screen for uploading and viewing PDFs with tabs for Due-list and Commission.
class PdfUploadScreen extends StatelessWidget {
  const PdfUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Uploads'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Due PDFs'),
              Tab(text: 'Commission PDFs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DuePdfUploadTab(),
            CommissionPdfUploadTab(),
          ],
        ),
      ),
    );
  }
}
