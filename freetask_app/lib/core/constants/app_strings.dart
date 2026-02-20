/// Centralized string constants for the Freetask application.
/// All user-facing strings should use these constants to ensure consistency
/// and enable easier localization in the future.
class AppStrings {
  AppStrings._();

  // ============================================================================
  // Common Actions & Buttons
  // ============================================================================
  static const String btnSave = 'Simpan';
  static const String btnCancel = 'Batal';
  static const String btnDelete = 'Padam';
  static const String btnEdit = 'Edit';
  static const String btnConfirm = 'Sahkan';
  static const String btnContinue = 'Teruskan';
  static const String btnBack = 'Kembali';
  static const String btnClose = 'Tutup';
  static const String btnRetry = 'Cuba Lagi';
  static const String btnRefresh = 'Segar semula';
  static const String btnSubmit = 'Hantar';
  static const String btnSend = 'Hantar';
  static const String btnLogout = 'Log Keluar';
  static const String btnLogin = 'Log Masuk';
  static const String btnRegister = 'Daftar';
  static const String btnGoHome = 'Pergi ke Home';
  static const String btnViewDetails = 'Lihat Butiran';
  static const String btnOpenChat = 'Buka Chat';

  // ============================================================================
  // Navigation
  // ============================================================================
  static const String navHome = 'Home';
  static const String navJobs = 'Jobs';
  static const String navChats = 'Chats';
  static const String navProfile = 'Profil';
  static const String navSettings = 'Tetapan';
  static const String navAdmin = 'Admin';
  static const String navMarketplace = 'Marketplace';

  // ============================================================================
  // Job Status Labels
  // ============================================================================
  static const String jobStatusPending = 'Menunggu';
  static const String jobStatusAccepted = 'Diterima';
  static const String jobStatusInProgress = 'Dalam Progress';
  static const String jobStatusCompleted = 'Selesai';
  static const String jobStatusCancelled = 'Dibatalkan';
  static const String jobStatusRejected = 'Ditolak';
  static const String jobStatusDisputed = 'Dispute';

  // ============================================================================
  // Escrow Status Labels
  // ============================================================================
  static const String escrowStatusPending = 'Menunggu';
  static const String escrowStatusHeld = 'Dipegang';
  static const String escrowStatusDisputed = 'Dispute';
  static const String escrowStatusReleased = 'Dilepaskan';
  static const String escrowStatusRefunded = 'Dipulangkan';
  static const String escrowStatusCancelled = 'Dibatalkan';

  // ============================================================================
  // Job Actions
  // ============================================================================
  static const String jobActionAccept = 'Terima';
  static const String jobActionReject = 'Tolak';
  static const String jobActionStart = 'Mula';
  static const String jobActionComplete = 'Selesai';
  static const String jobActionDispute = 'Dispute';
  static const String jobActionCancel = 'Batalkan';
  static const String jobActionReview = 'Tulis Review';

  // ============================================================================
  // Success Messages
  // ============================================================================
  static const String successJobAccepted =
      'Job diterima. Anda boleh mulakan apabila bersedia.';
  static const String successJobRejected =
      'Job telah ditolak dan dikemas kini.';
  static const String successJobStarted =
      'Job dimulakan! Status kini In Progress.';
  static const String successJobCompleted =
      'Job ditandakan selesai. Status kini Completed.';
  static const String successJobCancelled = 'Job dibatalkan.';
  static const String successDisputeSubmitted =
      'Dispute telah dihantar. Admin akan menyemak dan menghubungi anda jika perlu.';
  static const String successReviewSubmitted = 'Terima kasih atas review anda!';
  static const String successLogout = 'Anda telah log keluar.';

  // ============================================================================
  // Error Messages - Network
  // ============================================================================
  static const String errorNetwork = 'Ralat rangkaian berlaku. Sila cuba lagi.';
  static const String errorNoConnection =
      'Tidak dapat hubungi server. Sila semak:\n'
      '1. Backend API sedang berjalan?\n'
      '2. URL API betul? (Semak "Tukar API Server")\n'
      '3. CORS configuration betul? (untuk Web)';
  static const String errorTimeout =
      'Sambungan internet bermasalah. Sila periksa rangkaian anda.';
  static const String errorServerError =
      'Ralat pelayan. Sila cuba sebentar lagi.';

  // ============================================================================
  // Error Messages - Authentication
  // ============================================================================
  static const String errorInvalidCredentials = 'Email atau kata laluan salah.';
  static const String errorSessionExpired =
      'Sesi anda tamat. Sila login semula.';
  static const String errorUnauthorized =
      'Anda tidak mempunyai kebenaran untuk tindakan ini.';
  static const String errorEmailAlreadyRegistered =
      'Email ini sudah berdaftar. Sila log masuk.';

  // ============================================================================
  // Error Messages - Validation
  // ============================================================================
  static const String errorInvalidInput =
      'Sila semak semula maklumat yang diisi.';
  static const String errorNotFound = 'Sumber yang diminta tidak dijumpai.';
  static const String errorConflict =
      'Tindakan ini tidak dibenarkan dalam status semasa. Sila refresh dan cuba lagi.';
  static const String errorActionFailed = 'Tindakan tidak berjaya. Cuba lagi.';
  static const String errorGeneric = 'Ralat melaksanakan tindakan.';

  // ============================================================================
  // Error Messages - Specific
  // ============================================================================
  static const String errorLoadingJobs = 'Ralat memuat job.';
  static const String errorLoadingServices =
      'Tidak dapat memuatkan servis. Sila cuba lagi.';
  static const String errorLoadingProfile =
      'Profil gagal dimuat. Tarik untuk refresh atau log keluar & masuk semula.';
  static const String errorLoadingCategories = 'Gagal memuat kategori.';
  static const String errorLoadingEscrow = 'Gagal memuat escrow.';
  static const String errorInvalidAmount = 'Jumlah tidak sah / sila refresh';
  static const String errorCannotDetermineReviewee =
      'Tidak dapat menentukan penerima review.';

  // ============================================================================
  // Empty States
  // ============================================================================
  static const String emptyJobsClient = 'Tiada job sebagai client';
  static const String emptyJobsClientSubtitle =
      'Buka marketplace untuk hire freelancer atau cuba refresh sekiranya anda baru selesai membuat tempahan.';
  static const String emptyJobsFreelancer = 'Tiada job sebagai freelancer';
  static const String emptyJobsFreelancerSubtitle =
      'Belum ada job aktif. Semak Job Board atau kekalkan status sedia menerima kerja.';
  static const String emptyServicesTitle = 'Tiada servis ditemui';
  static const String emptyServicesSubtitle =
      'Tiada servis ditemui untuk carian ini.';
  static const String emptyChatsTitle = 'Tiada perbualan';
  static const String emptyChatsSubtitle =
      'Mulakan perbualan dengan hire freelancer atau terima job.';
  static const String emptyDataGeneric = 'Tiada data';

  // ============================================================================
  // Loading States
  // ============================================================================
  static const String loadingGeneric = 'Memuatkan...';
  static const String loadingJobs = 'Memuatkan jobs...';
  static const String loadingServices = 'Memuatkan servis...';
  static const String loadingProfile = 'Memuatkan profil...';
  static const String loadingEscrow = 'Memuat status escrow...';
  static const String loadingApp = 'Menyediakan aplikasi...';
  static const String searching = 'Mencari...';

  // ============================================================================
  // Confirmation Dialogs
  // ============================================================================
  static const String confirmLogoutTitle = 'Log Keluar?';
  static const String confirmLogoutMessage =
      'Adakah anda pasti mahu log keluar dari akaun anda?';

  static const String confirmCancelJobTitle = 'Batalkan Job?';
  static const String confirmCancelJobMessage =
      'Adakah anda pasti mahu batalkan job ini? Tindakan ini tidak boleh dibatalkan.';

  static const String confirmRejectJobTitle = 'Tolak Job?';
  static const String confirmRejectJobMessage =
      'Adakah anda pasti mahu tolak job ini? Client akan dimaklumkan.';

  static const String confirmDisputeTitle = 'Hantar Dispute?';
  static const String confirmDisputeMessage =
      'Dispute anda akan dihantar kepada admin untuk semakan. Pastikan anda telah jelaskan masalah dengan jelas.';

  static const String confirmEscrowActionTitle = 'Sahkan Tindakan Escrow';
  static const String confirmEscrowReleaseMessage =
      'Lepaskan dana kepada freelancer? Tindakan ini tidak boleh dibatalkan.';
  static const String confirmEscrowRefundMessage =
      'Pulangkan dana kepada client? Tindakan ini tidak boleh dibatalkan.';
  static const String confirmEscrowHoldMessage =
      'Pegang dana untuk job ini? Dana akan dipegang sehingga tindakan seterusnya.';

  // ============================================================================
  // Dispute
  // ============================================================================
  static const String disputeReasonTitle = 'Nyatakan sebab dispute';
  static const String disputeReasonHint = 'Contoh: Kerja tidak memenuhi skop.';
  static const String disputeReasonHelper =
      'Kongsikan ringkasan jelas tentang isu. Sertakan fakta penting tetapi elak maklumat sensitif.';
  static const String disputeReasonInfo =
      'Dispute anda akan dihantar kepada admin untuk semakan. Sila jelaskan masalah anda dengan jelas.';
  static const String disputeReasonMinError = 'Minimum 10 aksara diperlukan.';
  static const String disputeInProgress = 'Dispute sedang disemak';

  // ============================================================================
  // Job Details
  // ============================================================================
  static const String jobIdLabel = 'ID Job';
  static const String serviceIdLabel = 'ID Servis';
  static const String clientLabel = 'Client';
  static const String freelancerLabel = 'Freelancer';
  static const String amountLabel = 'Jumlah';
  static const String statusLabel = 'Status';
  static const String createdAtLabel = 'Dicipta';
  static const String updatedAtLabel = 'Dikemas kini';
  static const String disputeReasonLabel = 'Sebab Dispute';
  static const String escrowLabel = 'Escrow';

  // ============================================================================
  // Roles
  // ============================================================================
  static const String roleClient = 'Client';
  static const String roleFreelancer = 'Freelancer';
  static const String roleAdmin = 'Admin';

  // ============================================================================
  // Misc
  // ============================================================================
  static const String dateUnavailable = 'Tarikh tidak tersedia';
  static const String priceUnavailable =
      'Harga belum tersedia / invalid, sila refresh';
  static const String reviewSubmitted = 'Review dihantar';
  static const String adminOnly = 'Admin sahaja';
  static const String unavailable = 'Tidak tersedia';
  static const String noAdditionalInfo = 'Tiada maklumat tambahan.';

  // ============================================================================
  // Server Cold-Start Messages
  // ============================================================================
  static const String serverConnecting = 'Sedang menghubungi server... ☕';
  static const String serverWarmingUp =
      'Server sedang disiapkan, sila tunggu...';
  static const String serverAlmostReady = 'Hampir siap!';
  static const String serverOnline = 'Server online! Sedang log masuk...';
  static const String serverUnreachable =
      'Pelayan tidak dapat dihubungi. Sila periksa sambungan internet anda.';

  // ============================================================================
  // Avatar / Profile
  // ============================================================================
  static const String avatarFieldLabel = 'Gambar Profil (pilihan)';
  static const String avatarUploadPending =
      'Gambar profil akan dimuat naik selepas pendaftaran.';
  static const String avatarUploadSuccess =
      'Gambar profil berjaya dikemaskini!';

  // ============================================================================
  // Hire Confirmation
  // ============================================================================
  static const String hireConfirmTitle = 'Ringkasan Tempahan';
  static const String hireConfirmServiceFee = 'Harga Servis';
  static const String hireConfirmPlatformFee = 'Caj Platform';
  static const String hireConfirmTotal = 'Jumlah Bayar';
  static const String hireConfirmBtn = 'Teruskan Hire';

  // ============================================================================
  // Freelancer Trust
  // ============================================================================
  static const String freelancerBadgeNew = 'Baru';
  static const String freelancerBadgeVerified = 'Terverifikasi';
  static const String freelancerJobsCompleted = 'job selesai';
  static const String emptyFreelancerActivateCta = 'Aktifkan Status Anda';
  static const String emptyFreelancerMsg =
      'Belum ada job. Pastikan status anda aktif supaya boleh ditemui client.';
  static const String emptyClientMsg =
      'Belum ada job. Explore marketplace untuk hire freelancer.';
  static const String emptyClientCta = 'Explore Services';

  // ============================================================================
  // What's Next? Guidance
  // ============================================================================
  static const String whatsNextTitle = 'Apa Seterusnya?';

  static const String whatsNextJobPending =
      'Tunggu freelancer terima job anda. Anda akan dimaklumkan apabila freelancer menerima atau menolak.';

  static const String whatsNextJobAccepted =
      'Freelancer akan mulakan kerja tidak lama lagi. Anda boleh berhubung melalui chat untuk perbincangan lanjut.';

  static const String whatsNextJobInProgress =
      'Kerja sedang dijalankan. Sila pantau progress melalui chat dan tunggu freelancer tandakan selesai.';

  static const String whatsNextJobCompleted =
      'Job telah selesai! Sila semak hasil kerja dan tinggalkan review untuk freelancer.';

  static const String whatsNextJobCompletedFreelancer =
      'Anda telah tandakan job sebagai selesai. Tunggu client semak dan lepaskan bayaran.';

  static const String whatsNextJobDisputed =
      'Dispute sedang disemak oleh admin. Anda akan dihubungi jika diperlukan.';
}
