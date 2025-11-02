# Ideogram Character Edit Tool Implementation

## Overview
This document describes the implementation of the Ideogram Character Edit tool using brush mask functionality.

## Features
- Brush-based mask painting interface
- Real-time brush preview with adjustable size
- Erase functionality for mask corrections
- Undo/clear operations
- Seamless integration with existing AI tools architecture
- Theme-adaptive UI following the app's design system

## Components

### 1. Mask Brush Painter Widget (`lib/widgets/mask_brush_painter.dart`)
A full-screen painting interface that allows users to:
- Paint masks on images using touch/mouse gestures
- Adjust brush size (5-100px)
- Switch between paint and erase modes
- Undo strokes or clear entire mask
- Generate mask as PNG image (white = edit area, black = preserve)

**Key Features:**
- Scales image to fit screen while maintaining aspect ratio
- Real-time visual feedback with semi-transparent red overlay
- Generates proper mask format for fal.ai API

### 2. API Integration (`lib/services/fal_ai_service.dart`)
Added `ideogramCharacterEdit()` method:
```dart
Future<Uint8List> ideogramCharacterEdit({
  required Uint8List inputImageBytes,
  required Uint8List maskImageBytes,
  required String prompt,
})
```

**API Endpoint:** `https://queue.fal.run/fal-ai/ideogram/character/edit`

**Payload:**
- `prompt`: Description of desired edit
- `image_url`: Original image URL
- `mask_url`: Mask image URL (white = edit, black = preserve)
- `reference_image_urls`: Array of 1-4 reference image URLs showing the character to preserve

### 3. Editor Integration (`lib/screens/editor_page.dart`)

#### New Method: `_onCharacterBrushEdit()`
Handles the character edit workflow:
1. Shows prompt + reference selection sheet
2. Opens brush painter for mask creation
3. Uploads mask to Supabase storage
4. Enqueues AI job with prompt, mask URL, and reference URLs
5. Tracks job progress with AI jobs service

#### New Bottom Sheet: `_showCharacterEditBottomSheet()`
Three-step process:
1. **Prompt Entry:** User describes desired edit
2. **Reference Selection:** User selects 1-4 reference images showing the character to preserve
3. **Mask Painting:** User paints over the area to edit

**Design Features:**
- Gradient header with brush icon
- Clear instructions and info boxes
- Smooth transitions between steps
- Error handling for empty inputs

### 4. UI Integration
Added new AI tool chip to tools row:
```dart
_aiChip(Icons.brush_rounded, 'Mask Edit', _onCharacterBrushEdit)
```

Positioned between "Upscale" and "Character" tools for logical workflow.

### 5. Database Integration
Added to Supabase `tools` table:
```sql
('ideogram_character_edit', 'Character Edit (Mask)', 'ai', 0, 'free_trial')
```

## Architecture

### Data Flow
1. User taps "Mask Edit" in AI tools row
2. Prompt input + reference selection sheet appears
3. User enters description
4. User selects 1-4 reference images from library (character to preserve)
5. User taps "Paint Mask"
6. Brush painter opens with current image
7. User paints mask over desired edit area
8. On complete, mask is uploaded to Supabase
9. AI job is enqueued with prompt, mask URL, and reference URLs
10. Backend processes job via fal.ai API with all parameters
11. Result is applied to editor when complete

### Backend Integration
The tool integrates with existing AI jobs pipeline:
- Uses `AiJobsRepository` for job management
- Leverages `AiJobsService` for processing
- Follows same pattern as other AI tools
- Supports job status tracking and live updates

## Design System Compliance
All UI components follow the app's design system:
- **Colors:** Primary purple (#6366F1), primary blue (#4A90E2)
- **Gradients:** Three-color gradients for buttons and headers
- **Borders:** 16px corner radius consistently
- **Typography:** Google Fonts Inter with proper weights
- **Shadows:** Soft shadows with theme-aware opacity
- **Theme Support:** Adapts to light/dark mode

## User Experience
1. **Discoverability:** Clear icon (brush) and label in AI tools row
2. **Guidance:** Info boxes explain what to do next
3. **Feedback:** Visual indicators for painted areas
4. **Control:** Adjustable brush size, undo, clear
5. **Error Handling:** Validation for empty prompts/masks
6. **Progress:** Loading states and snackbar notifications

## Testing Recommendations
1. Test mask generation with various image sizes
2. Verify mask upload to Supabase
3. Test brush painting on different devices (touch/mouse)
4. Validate API integration with fal.ai
5. Test error scenarios (network failures, API errors)
6. Verify undo/redo functionality in AI session
7. Test theme switching during mask painting

## Future Enhancements
- Brush opacity control
- Multiple brush types (soft, hard edges)
- Mask preview before submission
- Save masks for reuse
- Batch editing with multiple masks
- Reference image support alongside mask

## Dependencies
- `flutter/material.dart` - UI framework
- `dart:ui` - Image rendering
- `dart:typed_data` - Binary data handling
- Google Fonts - Typography
- Existing app services (MediaRepository, AiJobsService, etc.)

## API Documentation
See fal.ai documentation: https://fal.ai/models/fal-ai/ideogram/character/edit

