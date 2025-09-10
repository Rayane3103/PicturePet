# MediaPet - Flutter Photo Editing App

## Overview

MediaPet is a comprehensive Flutter photo editing application that combines traditional manual editing tools with AI-powered features. The app operates on a credit-based system with tiered subscriptions, allowing users to create and manage photo editing projects while accessing various tools based on their subscription level. Built with Supabase as the backend, it provides secure user authentication, project management, and a sophisticated database schema to support the credit economy and tool usage tracking.

## User Preferences

Preferred communication style: Simple, everyday language.

## System Architecture

### Frontend Architecture
- **Framework**: Flutter cross-platform framework supporting mobile (Android/iOS), web, and desktop platforms
- **UI Components**: Material Design with custom theming using Google Fonts
- **Image Processing**: Multiple image processing libraries including `pro_image_editor`, `image`, `flutter_image_compress`, and `image_editor`
- **State Management**: Flutter's built-in state management with StatefulWidget pattern
- **Navigation**: Flutter's routing system with deep linking support via `app_links` package
- **Storage**: Local storage using `flutter_secure_storage` and `shared_preferences`

### Backend Architecture
- **Database**: Supabase (PostgreSQL) with comprehensive schema including 7 core tables, 2 views, and 8 functions
- **Authentication**: Supabase Auth integrated with Row Level Security (RLS) for data protection
- **Real-time Features**: Supabase real-time subscriptions for live data updates
- **API Layer**: Supabase client SDK for Flutter providing RESTful API access

### Data Architecture
- **User Management**: Profiles extending Supabase Auth with app-specific data
- **Credit System**: Transaction-based credit tracking with deduction and addition functions
- **Project Management**: Hierarchical project structure with edit history tracking
- **Tool System**: Flexible tool definition with credit costs and tier restrictions
- **Subscription Tiers**: Five-tier system (Free Trial, Bronze, Silver, Gold, Platinum) with progressive feature unlocking

### Authentication and Authorization
- **Primary Auth**: Supabase Auth with email/password authentication
- **Social Authentication**: Google OAuth and Facebook OAuth integration with proper redirect URL configuration
- **Deep Linking**: Custom URL schemes for OAuth callbacks (`io.supabase.flutter://login-callback/`)
- **Security**: Row Level Security policies ensuring users can only access their own data
- **Session Management**: Persistent sessions across app restarts using secure storage

### Image Processing Pipeline
- **Image Loading**: Support for both local assets and network images
- **Optimization**: Automatic image downscaling to prevent memory issues (max 2048px)
- **Editor Integration**: Pro Image Editor for comprehensive editing capabilities
- **Manual Tools**: Basic adjustments (brightness, contrast, crop, rotate, saturation, sharpness)
- **AI Tools**: Integration with FAL-AI services for advanced image manipulation

## External Dependencies

### Core Services
- **Supabase**: Primary backend service providing database, authentication, and real-time features
- **Google OAuth**: Social authentication via Google Cloud Console integration
- **Facebook OAuth**: Social authentication through Facebook Developer platform

### AI Services
- **FAL-AI Platform**: External AI image processing services including:
  - Ideogram v3 edit capabilities
  - Character editing tools  
  - Image reframing features
  - Progressive access based on subscription tiers

### Flutter Packages
- **Authentication & Storage**: `supabase_flutter`, `flutter_secure_storage`, `shared_preferences`
- **Image Processing**: `pro_image_editor`, `image`, `flutter_image_compress`, `image_editor`, `image_picker`
- **UI Enhancement**: `google_fonts`, `flutter_staggered_grid_view`, `cupertino_icons`
- **Social Auth**: `google_sign_in`, `flutter_facebook_auth`
- **System Integration**: `app_links`, `url_launcher`, `path_provider`, `path`
- **Security**: `crypto`, `flutter_dotenv` for environment variable management

### Platform-Specific Integrations
- **Deep Linking**: Custom URL schemes configured in AndroidManifest.xml and iOS Info.plist
- **Web Support**: PWA capabilities with proper manifest configuration
- **Cross-Platform**: CMake configuration for Windows and Linux desktop support