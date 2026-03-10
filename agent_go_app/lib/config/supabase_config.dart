/// Supabase configuration constants.
/// Replace these with your project values or use environment variables.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://covwkeaxwcrpyfxverkz.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvdndrZWF4d2NycHlmeHZlcmt6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2MzczMjEsImV4cCI6MjA2NjIxMzMyMX0.eiXaZfiw4Tf0c9NkwhdbWms2va57Ohx6OjRfObtH4u4';

  /// Storage bucket for due-list PDFs
  static const String pdfBucket = 'due-pdfs';
  
  /// Storage bucket for commission PDFs
  static const String commissionBucket = 'commission-pdfs';
}
