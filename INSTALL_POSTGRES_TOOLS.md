# Install PostgreSQL Tools on Windows

Untuk migrate database, anda perlukan PostgreSQL command-line tools (`pg_dump` dan `psql`).

## Cara Install

### Pilihan 1: Install PostgreSQL Full (Recommended)

1. **Download PostgreSQL**: https://www.postgresql.org/download/windows/
   - Klik "Download the installer"
   - Pilih versi terbaru (contoh: PostgreSQL 16.x)

2. **Run Installer**:
   - Double-click file `.exe` yang di-download
   - Ikut wizard installation
   - **PENTING**: Pastikan tick checkbox "Command Line Tools" semasa installation

3. **Verify Installation**:
   ```bash
   pg_dump --version
   psql --version
   ```

### Pilihan 2: Install Tools-Only (Lighter)

1. **Download Binary Package**:
   - Pergi ke: https://www.enterprisedb.com/download-postgresql-binaries
   - Download ZIP file untuk Windows

2. **Extract dan Set Path**:
   - Extract ZIP file ke folder (contoh: `C:\PostgreSQL`)
   - Add `C:\PostgreSQL\bin` ke System PATH
   - Restart terminal/PowerShell

3. **Verify Installation**:
   ```bash
   pg_dump --version
   psql --version
   ```

## Selepas Install

Run migration script:
```bash
cd c:\Users\USER\freetask-app-3
.\migrate-database.bat
```

---

## Alternative: Manual Migration (Jika tak nak install tools)

Anda boleh guna Supabase Studio atau tools GUI seperti:
- **DBeaver** (free, cross-platform)
- **pgAdmin** (free, PostgreSQL official)
- **TablePlus** (paid, but has free trial)

Langkah manual:
1. Connect ke Render database
2. Export schema dan data
3. Connect ke Supabase database  
4. Import schema dan data
