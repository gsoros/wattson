/// Cycling performance metrics computed from ride data.
///
/// All functions are pure — given the same inputs they always return the same
/// result, so they are safe to call from build methods.
// ignore_for_file: dangling_library_doc_comments

/// Intensity Factor: the ratio of Normalized Power to Functional Threshold
/// Power.
///
/// Returns null when either input is null or zero.
double? computeIF(double? np, double? ftp) {
  if (np == null || ftp == null || ftp <= 0) return null;
  return np / ftp;
}

/// Training Stress Score: a measure of training load.
///
/// Formula: TSS = (seconds × NP × IF) / (FTP × 3600) × 100
///
/// Returns null when any required input is missing or zero.
double? computeTSS(double? np, double? ftp, double? seconds) {
  if (np == null || ftp == null || seconds == null || ftp <= 0 || seconds <= 0) return null;
  final if_ = np / ftp;
  return (seconds * np * if_) / (ftp * 3600) * 100;
}
