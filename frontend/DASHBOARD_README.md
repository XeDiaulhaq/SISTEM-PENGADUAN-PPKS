# Dashboard Page - Flutter Implementation

# Dashboard Page - Flutter Implementation

This is a Flutter implementation of the Dashboard page that displays and manages uploaded video reports.

## 📏 Spacing & Layout Guidelines

All spacing and layout measurements have been carefully matched to the React/TypeScript implementation from `ui⁄ux/components/DashboardPage.tsx`.

### Container & Padding
- **Main Container**: `max-width: 1280px` (max-w-7xl) - Centered with auto margins
- **Horizontal Padding**: `16px` (px-4 = 1rem)
- **Top Padding**: `128px` (pt-32 = 8rem)
- **Bottom Padding**: `80px` (pb-20 = 5rem)

### Header Section
- **Title Font Size**: `36px` (text-3xl)
- **Title Margin Bottom**: `8px` (mb-2 = 0.5rem)
- **Subtitle Font Size**: `20px` (text-xl)
- **Section Margin Bottom**: `32px` (mb-8 = 2rem)

### Stats Grid
- **Grid Gaps**: `24px` (gap-6 = 1.5rem) both horizontal and vertical
- **Card Padding**: `24px` (p-6 = 1.5rem)
- **Card Border Radius**: `12px` (rounded-lg)
- **Title Font Size**: `14px` (text-sm)
- **Value Font Size**: `30px` (text-3xl)
- **Title Margin Bottom**: `4px` (mb-1)
- **Icon Container Padding**: `12px` (p-3)
- **Breakpoints**:
  - Desktop (>1024px): 4 columns
  - Tablet (768-1024px): 2 columns
  - Mobile (<768px): 1 column

### Video List Card
- **Card Padding**: `24px` (p-6 = 1.5rem)
- **Title Font Size**: `24px` (text-2xl)
- **Filter Text Spacing**: `12px` (ml-3 = 0.75rem)
- **Content Margin Top**: `24px` (mb-6 = 1.5rem)
- **Item Spacing**: `16px` (space-y-4 = 1rem)

### Video Card
- **Card Padding**: `20px` (p-4 md:p-5)
- **Icon Container Padding**:
  - Mobile: `10px` (p-2.5)
  - Desktop: `12px` (p-3)
- **Icon Size**:
  - Mobile: `20px` (w-5 h-5)
  - Desktop: `24px` (w-6 h-6)
- **Gap between Icon and Content**:
  - Mobile: `12px` (gap-3)
  - Desktop: `16px` (gap-4)
- **Info Chips Spacing**:
  - Mobile: `8px` (gap-2)
  - Desktop: `12px` (gap-3)
- **Button Spacing**: `8px` (gap-2)
- **Content Section Spacing**: `16px` (between rows)

### Status Badges
- **Padding**:
  - Mobile: `horizontal: 8px, vertical: 4px` (px-2 py-0.5)
  - Desktop: `horizontal: 12px, vertical: 6px` (px-3 py-1.5)
- **Icon Size**:
  - Mobile: `12px` (w-3 h-3)
  - Desktop: `14px` (w-4 h-4)
- **Text Size**:
  - Mobile: `10px` (text-xs)
  - Desktop: `12px` (text-xs)
- **Border Radius**: `16px` (rounded-2xl)

### Buttons
- **Padding**: `horizontal: 16px, vertical: 12px`
- **Icon Size**:
  - Mobile: `14px` (w-3.5 h-3.5)
  - Desktop: `16px` (w-4 h-4)
- **Text Size**:
  - Mobile: `12px` (text-xs)
  - Desktop: `14px` (text-sm)
- **Gap**: `6px` (gap-1.5)

### Video Detail Dialog
- **Max Width**: `900px` (max-w-4xl)
- **Max Height**: `700px` (max-h-[90vh])
- **Inset Padding**: `16px` (all sides)
- **Header/Content Padding**: `24px`
- **Section Padding**: `16px`
- **Section Spacing**: `16px` (between sections)
- **Info Row Spacing**: `8px` (mb-2)

### Empty State
- **Container Padding**: `48px` (py-12 = 3rem)
- **Icon Size**: `64px` (w-16 h-16 = 4rem)
- **Icon Margin Bottom**: `16px` (mb-4 = 1rem)
- **Text Margin Top**: `8px` (mt-2 = 0.5rem)
- **Primary Text Size**: `18px`
- **Secondary Text Size**: `14px` (text-sm)

### Responsive Breakpoints
Following Tailwind CSS defaults:
- **sm**: 640px
- **md**: 768px
- **lg**: 1024px
- **xl**: 1280px

### Color Palette
**Light Mode:**
- Background: `#FAFAFA`
- Card: `#FFFFFF`
- Border: `#E5E5E5`
- Text Primary: `#000000`
- Text Secondary: `#737373`
- Text Muted: `#A3A3A3`

**Dark Mode:**
- Background: `#0A0A0A`
- Card: `#171717`
- Card Hover: `#262626`
- Border: `#262626` / `#404040`
- Text Primary: `#FFFFFF`
- Text Secondary: `#D4D4D4`
- Text Muted: `#A3A3A3`

**Accent Colors:**
- Blue: `#3B82F6` (light) / `#60A5FA` (dark)
- Green: `#22C55E`
- Yellow: `#F59E0B`
- Red: `#EF4444`
- Purple: `#A855F7`

### Conversion Reference
Tailwind → Flutter EdgeInsets:
- `px-1` = `horizontal: 4px`
- `px-2` = `horizontal: 8px`
- `px-3` = `horizontal: 12px`
- `px-4` = `horizontal: 16px`
- `px-6` = `horizontal: 24px`
- `py-1` = `vertical: 4px`
- `py-2` = `vertical: 8px`
- `py-3` = `vertical: 12px`
- `py-4` = `vertical: 16px`
- `py-6` = `vertical: 24px`

Tailwind → Flutter SizedBox:
- `gap-1` = `SizedBox: 4px`
- `gap-2` = `SizedBox: 8px`
- `gap-3` = `SizedBox: 12px`
- `gap-4` = `SizedBox: 16px`
- `gap-6` = `SizedBox: 24px`

Tailwind → Flutter Spacing:
- `mb-1` = `SizedBox(height: 4)`
- `mb-2` = `SizedBox(height: 8)`
- `mb-4` = `SizedBox(height: 16)`
- `mb-6` = `SizedBox(height: 24)`
- `mb-8` = `SizedBox(height: 32)`

---

## Dashboard Page - Flutter Implementation

## 📋 Features Implemented

### ✅ Core Features
- **Real-time Video Monitoring**: Auto-refresh every 3 seconds to detect new reports
- **Status Management**: Track reports through three states:
  - 🔵 **Baru (New)** - Newly submitted reports
  - 🟠 **Diproses (Processing)** - Reports being handled
  - 🟢 **Selesai (Completed)** - Resolved reports

### 📊 Statistics Dashboard
- **Total Laporan**: Total count of all reports
- **Laporan Hari Ini**: Reports submitted today
- **Sedang Diproses**: Reports currently being processed
- **Selesai Diproses**: Completed reports

### 🔍 Filtering System
- Click on any stat card to filter reports
- Filter options: All, Today, Processing, Completed
- Reset filter button for quick access to all reports

### 📹 Video Report Details
Each report includes:
- Video filename and metadata (date, time, size)
- Blur type (Gaussian/Pixelation)
- Location of incident
- Detailed description
- Optional reporter contact (email/phone)
- Status management buttons

### 🎨 UI Components

#### 1. **Stat Cards**
- Interactive cards showing statistics
- Visual indicators with icons and colors
- Click to filter reports

#### 2. **Video Cards**
- Compact view of each report
- Status badges with color coding
- Quick action buttons (View, Download, Process/Complete)
- Responsive layout for mobile and desktop

#### 3. **Detail Dialog**
- Full report information
- Video preview placeholder
- Organized sections with icons
- Status update actions

## 📁 File Structure

```
lib/
├── models/
│   └── video_model.dart          # Video data model with status enum
├── services/
│   └── video_storage_service.dart # Local storage management
└── pages/
    └── dashboard_page.dart        # Main dashboard implementation
```

## 🔧 Dependencies Added

```yaml
dependencies:
  shared_preferences: ^2.2.2  # For local data persistence
```

## 🚀 Usage

The dashboard is accessible via the `/dashboard` route after admin login:

```dart
Navigator.pushNamed(context, '/dashboard');
```

## 📱 Responsive Design

The dashboard adapts to different screen sizes:
- **Desktop (>900px)**: 4 columns for stat cards
- **Tablet (600-900px)**: 2 columns for stat cards
- **Mobile (<600px)**: 1 column for stat cards

## 💾 Data Storage

Reports are stored locally using `shared_preferences`:
- Automatic save on status updates
- Sample data initialized on first run
- Persistent across app sessions

## 🎯 Status Workflow

```
📝 Baru (New)
    ↓ [Proses Button]
⏳ Diproses (Processing)
    ↓ [Selesai Button]
✅ Selesai (Completed)
```

## 🔄 Auto-refresh

The dashboard automatically refreshes every 3 seconds to:
- Detect new reports from the Recorder page
- Update existing report statuses
- Keep data synchronized

## 🎨 Color Scheme

- **Blue**: New reports, primary actions
- **Orange**: Processing status
- **Green**: Completed status
- **Red**: Location indicators
- **Purple**: Additional info (phone)

## 📝 Sample Data

The system includes 3 sample reports:
1. **Pelecehan Verbal** (New) - Verbal harassment case
2. **Intimidasi** (Processing) - Intimidation case
3. **Kekerasan** (Completed) - Violence case from yesterday

## 🔐 Admin Features

- View all submitted reports
- Process new reports
- Mark reports as completed
- Download video evidence
- View detailed report information
- Filter and search reports

## 🎭 UI/UX Highlights

- **Material Design 3** components
- **Smooth animations** for status changes
- **Snackbar notifications** for user feedback
- **Empty states** with helpful messages
- **Loading indicators** during data fetch
- **Modal dialogs** for detailed views

## 🔮 Future Enhancements

Potential additions:
- [ ] Video player integration
- [ ] Export reports to PDF
- [ ] Email notifications
- [ ] Advanced search and filters
- [ ] Report analytics and charts
- [ ] User role management
- [ ] Batch operations

## 🐛 Known Limitations

- Video preview not implemented (placeholder shown)
- Download feature shows notification only
- No backend integration yet (local storage only)
- No real-time WebSocket updates

## 💡 Tips

1. **Testing**: Use the Recorder page to add new reports
2. **Data Reset**: Clear app data to reset to sample data
3. **Status Update**: Click status buttons to change report state
4. **Details**: Click "Lihat" button to view full report information

---

**Created**: November 2025
**Version**: 1.0.0
**Framework**: Flutter 3.3+
**Platform**: Web, Android, iOS, Desktop
