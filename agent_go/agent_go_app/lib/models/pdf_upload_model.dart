/// Model for a PDF upload record.
class PdfUploadModel {
  final String id;
  final String userId;
  final String fileUrl;
  final String fileName;
  final int? fileSize;
  final String status; // uploaded, processing, completed, failed
  final int? recordsExtracted;
  final String? dueMonth;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? processedAt;

  const PdfUploadModel({
    required this.id,
    required this.userId,
    required this.fileUrl,
    required this.fileName,
    this.fileSize,
    this.status = 'uploaded',
    this.recordsExtracted,
    this.dueMonth,
    this.errorMessage,
    required this.createdAt,
    this.processedAt,
  });

  factory PdfUploadModel.fromJson(Map<String, dynamic> json) {
    return PdfUploadModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int?,
      status: json['status'] as String? ?? 'uploaded',
      recordsExtracted: json['records_extracted'] as int?,
      dueMonth: json['due_month'] as String?,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.tryParse(json['processed_at'] as String)
          : null,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isProcessing => status == 'processing';
  bool get isFailed => status == 'failed';
  bool get isUploaded => status == 'uploaded';
}
