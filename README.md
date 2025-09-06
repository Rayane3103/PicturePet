# Picture Pet - Supabase Database Schema

A comprehensive Postgres database schema for a Flutter photo editing app with credit-based AI tools, tiered subscriptions, and project management.

## 🏗️ Database Overview

The database is built on Supabase with the following key features:
- **User Authentication**: Integrated with Supabase Auth
- **Credit System**: Pay-per-use model for AI tools
- **Tiered Subscriptions**: 5 subscription levels with different features
- **Project Management**: Store and track image editing projects
- **Tool Management**: Manual and AI-powered editing tools
- **Row Level Security**: Users can only access their own data

## 📊 Database Schema

### Core Tables

#### 1. **tiers** - Subscription Plans
Stores different subscription tiers with pricing and limits.

| Column | Type | Description |
|--------|------|-------------|
| `id` | SERIAL | Primary key |
| `name` | user_tier | Tier identifier (free_trial, bronze, silver, gold, platinum) |
| `display_name` | VARCHAR(50) | Human-readable tier name |
| `price` | DECIMAL(10,2) | Monthly price in USD |
| `credits` | INTEGER | Credits included with tier |
| `storage_gb` | INTEGER | Storage limit in GB |
| `max_projects` | INTEGER | Maximum projects allowed (NULL = unlimited) |

#### 2. **tools** - Available Editing Tools
Defines all available tools with credit costs and tier requirements.

| Column | Type | Description |
|--------|------|-------------|
| `id` | SERIAL | Primary key |
| `name` | VARCHAR(100) | Tool identifier |
| `display_name` | VARCHAR(100) | Human-readable tool name |
| `type` | tool_type | 'manual' or 'ai' |
| `credit_cost` | INTEGER | Credits required to use tool |
| `tier_minimum` | user_tier | Minimum tier required |

#### 3. **profiles** - User Profiles
Extends Supabase Auth with app-specific user data.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | References auth.users.id |
| `username` | VARCHAR(50) | Unique username |
| `email` | VARCHAR(255) | User email |
| `tier` | user_tier | Current subscription tier |
| `credits` | INTEGER | Available credits |
| `storage_used_gb` | DECIMAL(10,3) | Current storage usage |
| `max_storage_gb` | INTEGER | Storage limit for tier |
| `max_projects` | INTEGER | Project limit for tier |
| `trial_started_at` | TIMESTAMPTZ | When trial began |
| `trial_ends_at` | TIMESTAMPTZ | When trial expires |

#### 4. **projects** - User Projects
Stores image editing projects.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | References profiles.id |
| `name` | VARCHAR(255) | Project name |
| `original_image_url` | TEXT | Original image URL |
| `output_image_url` | TEXT | Final edited image URL |
| `thumbnail_url` | TEXT | Thumbnail URL |
| `file_size_bytes` | BIGINT | File size in bytes |

#### 5. **project_edits** - Individual Edits
Tracks each edit made to a project.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `project_id` | UUID | References projects.id |
| `tool_id` | INTEGER | References tools.id |
| `edit_name` | VARCHAR(255) | Name of the edit |
| `parameters` | JSONB | Tool parameters |
| `input_image_url` | TEXT | Input image for this edit |
| `output_image_url` | TEXT | Output image from this edit |
| `credit_cost` | INTEGER | Credits spent on this edit |
| `status` | VARCHAR(50) | Edit status (pending, completed, failed) |

#### 6. **credit_transactions** - Credit History
Logs all credit transactions (spend, earn, admin adjustments).

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | References profiles.id |
| `type` | transaction_type | 'spend', 'earn', or 'admin_adjustment' |
| `amount` | INTEGER | Credit amount |
| `balance_before` | INTEGER | Credits before transaction |
| `balance_after` | INTEGER | Credits after transaction |
| `description` | TEXT | Transaction description |
| `reference_id` | UUID | Related entity ID |
| `reference_type` | VARCHAR(50) | Type of related entity |

#### 7. **tool_usage_log** - Tool Usage Tracking
Comprehensive logging of all tool usage.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | References profiles.id |
| `project_id` | UUID | References projects.id |
| `project_edit_id` | UUID | References project_edits.id |
| `tool_id` | INTEGER | References tools.id |
| `credit_cost` | INTEGER | Credits spent |
| `parameters` | JSONB | Tool parameters used |
| `success` | BOOLEAN | Whether tool usage succeeded |
| `error_message` | TEXT | Error message if failed |

### Custom Types

```sql
-- User subscription tiers
CREATE TYPE user_tier AS ENUM (
    'free_trial', 'bronze', 'silver', 'gold', 'platinum'
);

-- Tool types
CREATE TYPE tool_type AS ENUM ('manual', 'ai');

-- Transaction types
CREATE TYPE transaction_type AS ENUM (
    'spend', 'earn', 'admin_adjustment'
);
```

## 🎯 Subscription Tiers

| Tier | Price | Credits | Storage | Projects | Features |
|------|-------|---------|---------|----------|----------|
| **Free Trial** | $0 | 50 | 2 GB | 5 | Manual tools only, 7 days |
| **Bronze** | $5 | 200 | 2 GB | 10 | Basic AI tools |
| **Silver** | $10 | 600 | 10 GB | 50 | Advanced AI tools |
| **Gold** | $20 | 2000 | 50 GB | 200 | All AI tools |
| **Platinum** | $50 | 8000 | 200 GB | Unlimited | Premium AI tools |

## 🛠️ Available Tools

### Manual Tools (Free, All Tiers)
- **Brightness Adjustment** - Adjust image brightness
- **Contrast Adjustment** - Adjust image contrast
- **Crop Image** - Crop and resize images
- **Rotate Image** - Rotate images by any angle
- **Saturation Adjustment** - Adjust color saturation
- **Sharpness Adjustment** - Enhance image sharpness

### AI Tools (Credit-based, Tier-restricted)
- **fal-ai/ideogram/v3/edit** - 10 credits (Bronze+)
- **fal-ai/ideogram/character/edit** - 15 credits (Silver+)
- **fal-ai/ideogram/v3/reframe** - 20 credits (Gold+)
- **fal-ai/qwen-image-edit** - 30 credits (Platinum only)

## 🔐 Security Features

### Row Level Security (RLS)
- Users can only access their own data
- All tables have appropriate RLS policies
- Functions are marked as `SECURITY DEFINER` where needed

### Data Validation
- Credit amounts cannot be negative
- Storage usage cannot be negative
- Trial dates must be valid
- Foreign key constraints ensure data integrity

## 📈 Performance Features

### Indexes
- Primary keys and foreign keys are indexed
- Composite indexes for common query patterns
- Partial indexes for filtered queries
- Covering indexes for frequently accessed data

### Views
- **user_tool_availability** - Shows which tools user can use
- **user_project_summary** - User project statistics
- Optimized for common query patterns

## 🚀 Key Functions

### Core Functions
- **`can_use_tool(user_id, tool_id)`** - Check if user can use a tool
- **`deduct_credits(user_id, amount, ...)`** - Deduct credits from user
- **`add_credits(user_id, amount, ...)`** - Add credits to user
- **`upgrade_user_tier(user_id, new_tier)`** - Upgrade user subscription
- **`use_tool(user_id, tool_id, ...)`** - Use a tool (deducts credits)

### Utility Functions
- **`get_user_available_tools(user_id)`** - Get tools available to user
- **`get_user_projects_with_history(user_id, limit)`** - Get user projects
- **`get_user_credit_summary(user_id, days)`** - Get credit usage summary

## 📝 Example Usage

### Check Tool Availability
```sql
SELECT * FROM get_user_available_tools(auth.uid());
```

### Use a Tool
```sql
SELECT * FROM use_tool(
    auth.uid(),           -- user_id
    1,                    -- tool_id
    'project-uuid',       -- project_id
    '{"brightness": 0.2}', -- parameters
    'input-url',          -- input_image_url
    'Brightness +20%'     -- edit_name
);
```

### Get User Projects
```sql
SELECT * FROM get_user_projects_with_history(auth.uid(), 20);
```

### Upgrade User Tier
```sql
SELECT upgrade_user_tier(auth.uid(), 'silver');
```

## 🔄 Automatic Features

### Profile Creation
- Automatically creates profile when user signs up
- Sets default trial tier and credits
- Handles username generation from email

### Credit Management
- Automatic credit deduction when tools are used
- Transaction logging for all credit changes
- Balance validation before operations

### Trial Management
- Automatic trial expiration tracking
- Trial status updates
- Credit limits enforcement

## 📊 Analytics & Monitoring

### User Activity Tracking
- Tool usage patterns
- Credit spending analysis
- Project creation trends
- Storage usage monitoring

### Performance Metrics
- Tool processing times
- Success/failure rates
- Credit consumption patterns
- Storage utilization

## 🛡️ Best Practices

### Data Integrity
- Foreign key constraints
- Check constraints for business rules
- Transaction-based operations
- Comprehensive error handling

### Performance
- Strategic indexing
- Query optimization
- Efficient data structures
- Minimal data duplication

### Security
- Row-level security
- Function security
- Input validation
- Audit logging

## 🚀 Getting Started

1. **Database Setup**: The schema is automatically created via migrations
2. **User Registration**: Users automatically get profiles on signup
3. **Tool Usage**: Use the `use_tool()` function for all tool operations
4. **Credit Management**: Credits are automatically managed
5. **Tier Management**: Use `upgrade_user_tier()` for subscription changes

## 📚 Additional Resources

- **Example Queries**: See `example_queries.sql` for comprehensive examples
- **API Integration**: Functions are designed for easy Flutter integration
- **Monitoring**: Built-in views for analytics and monitoring
- **Scaling**: Schema designed for horizontal scaling and performance

---

*This database schema provides a robust foundation for a credit-based photo editing application with comprehensive user management, tool tracking, and subscription handling.*
