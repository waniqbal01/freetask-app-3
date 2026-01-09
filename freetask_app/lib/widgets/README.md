# Reusable Widgets Library

This directory contains reusable UI components for the Freetask application.

## Components

### Confirmation Dialog

**File**: `confirmation_dialog.dart`

A reusable confirmation dialog for destructive or important actions.

**Usage**:
```dart
final confirmed = await showConfirmationDialog(
  context: context,
  title: 'Confirm Logout',
  message: 'Are you sure you want to logout?',
  confirmText: 'Logout',
  isDangerous: true, // Shows red warning styling
);

if (confirmed == true) {
  // Perform action
}
```

**Features**:
- Customizable title, message, and button labels
- Danger variant with red styling (`isDangerous: true`)
- Icon support for visual context
- Material Design 3 compliant
- Returns `true` if confirmed, `false` or `null` if cancelled

**When to use**:
- Logout actions
- Delete operations
- Job cancellation/rejection
- Escrow fund actions (hold, release, refund)
- Any destructive action that cannot be easily undone

---

### Skeleton Loaders

**Directory**: `skeletons/`

Skeleton loaders provide better loading UX than `CircularProgressIndicator`.

#### Generic List Skeleton

**File**: `skeletons/generic_list_skeleton.dart`

**Usage**:
```dart
GenericListSkeleton(
  itemCount: 5,
  itemHeight: 100,
)
```

**When to use**:
- Generic list loading states
- When specific skeleton doesn't exist

#### Job Card Skeleton

**File**: `../features/jobs/widgets/job_card_skeleton.dart`

**Usage**:
```dart
ListView.separated(
  itemBuilder: (_, __) => const JobCardSkeleton(),
  separatorBuilder: (_, __) => const SizedBox.shrink(),
  itemCount: 4,
)
```

**When to use**:
- Loading job lists
- Job-related loading states

#### Service Card Skeleton

**File**: `../widgets/service_card.dart` (ServiceCardSkeleton class)

**Usage**:
```dart
ListView.builder(
  itemBuilder: (_, index) => const ServiceCardSkeleton(),
  itemCount: 6,
)
```

**When to use**:
- Loading service marketplace
- Service-related loading states

---

## Constants

### App Strings

**File**: `../constants/app_strings.dart`

Centralized Bahasa Malaysia strings for the entire app.

**Categories**:
- Common actions & buttons
- Navigation labels
- Job & Escrow status labels
- Success & error messages
- Empty state messages
- Confirmation dialog texts
- Form labels & hints

**Usage**:
```dart
import '../../core/constants/app_strings.dart';

Text(AppStrings.btnSave)
Text(AppStrings.jobStatusPending)
Text(AppStrings.successJobAccepted)
```

---

### App Formatters

**File**: `../constants/app_formatters.dart`

Standardized date and amount formatting utilities.

**Date Formatters**:
```dart
// "04 Dec 2025, 11:30 PM"
AppFormatters.formatDateTime(DateTime.now())

// "04 Dec 2025"
AppFormatters.formatDate(DateTime.now())

// "2 hari lalu"
AppFormatters.formatRelativeDate(DateTime.now().subtract(Duration(days: 2)))

// "Hari ini" or "Semalam" or formatted date
AppFormatters.formatSmartDate(DateTime.now())
```

**Amount Formatters**:
```dart
// "RM150.00"
AppFormatters.formatAmount(150.0)

// "RM150" or "RM150.50"
AppFormatters.formatAmountCompact(150.0)

// "RM1,500.00"
AppFormatters.formatAmountWithSeparator(1500.0)

// "Jumlah tidak sah"
AppFormatters.formatAmount(null) // Handles invalid amounts
```

---

## Best Practices

### 1. Always Use Constants

❌ **Bad**:
```dart
Text('Log Keluar')
Text('RM${amount.toStringAsFixed(2)}')
```

✅ **Good**:
```dart
Text(AppStrings.btnLogout)
Text(AppFormatters.formatAmount(amount))
```

### 2. Use Confirmation Dialogs for Destructive Actions

❌ **Bad**:
```dart
onPressed: () => deleteJob(jobId)
```

✅ **Good**:
```dart
onPressed: () async {
  final confirmed = await showConfirmationDialog(
    context: context,
    title: AppStrings.confirmDeleteTitle,
    message: AppStrings.confirmDeleteMessage,
    isDangerous: true,
  );
  if (confirmed == true) {
    await deleteJob(jobId);
  }
}
```

### 3. Use Skeleton Loaders Instead of CircularProgressIndicator

❌ **Bad**:
```dart
if (isLoading) {
  return Center(child: CircularProgressIndicator());
}
```

✅ **Good**:
```dart
if (isLoading) {
  return ListView.builder(
    itemBuilder: (_, __) => const JobCardSkeleton(),
    itemCount: 4,
  );
}
```

### 4. Standardize Empty States

✅ **Good Pattern**:
```dart
if (items.isEmpty) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
        SizedBox(height: 12),
        Text(AppStrings.emptyJobsClient),
        SizedBox(height: 8),
        Text(AppStrings.emptyJobsClientSubtitle),
        SizedBox(height: 16),
        FTButton(
          label: AppStrings.btnGoHome,
          onPressed: () => context.go('/home'),
        ),
      ],
    ),
  );
}
```

---

## Adding New Components

When creating new reusable components:

1. **Place in appropriate directory**:
   - Core widgets: `lib/core/widgets/`
   - Feature-specific: `lib/features/[feature]/widgets/`

2. **Document usage**:
   - Add to this README
   - Include code examples
   - Explain when to use

3. **Follow naming conventions**:
   - Widget files: `snake_case.dart`
   - Widget classes: `PascalCase`
   - Constants: `camelCase`

4. **Add to constants if applicable**:
   - Strings → `app_strings.dart`
   - Formatters → `app_formatters.dart`
   - Theme values → `app_theme.dart`

---

## Migration Guide

### Migrating Hardcoded Strings

1. Find hardcoded string in code
2. Check if constant exists in `app_strings.dart`
3. If not, add to appropriate category
4. Replace hardcoded string with constant
5. Test to ensure no regressions

### Migrating to Skeleton Loaders

1. Find `CircularProgressIndicator` usage
2. Determine what's being loaded (jobs, services, etc.)
3. Replace with appropriate skeleton loader
4. Adjust item count to match expected items
5. Test loading state appearance

---

## Future Enhancements

Potential additions to this library:

- [ ] Profile skeleton loader
- [ ] Chat message skeleton
- [ ] Info dialog component
- [ ] Success/error toast component
- [ ] Bottom sheet templates
- [ ] Form field components
- [ ] Avatar upload widget
- [ ] Rating display widget

---

**Last Updated**: December 4, 2025  
**Maintained By**: Freetask Development Team
