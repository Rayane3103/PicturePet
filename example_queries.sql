-- =====================================================
-- PICTURE_PET DATABASE - EXAMPLE QUERIES
-- =====================================================

-- 1. USER MANAGEMENT QUERIES
-- =====================================================

-- Get user profile with current tier and credits
SELECT 
    p.id,
    p.username,
    p.email,
    p.tier,
    p.credits,
    p.storage_used_gb,
    p.max_storage_gb,
    p.max_projects,
    p.is_trial_active,
    p.trial_ends_at
FROM profiles p
WHERE p.id = auth.uid();

-- Check if user can upgrade to a specific tier
SELECT 
    t.name as current_tier,
    t.credits as current_credits,
    t.storage_gb as current_storage,
    t.max_projects as current_max_projects,
    nt.name as new_tier,
    nt.credits as new_credits,
    nt.storage_gb as new_storage,
    nt.max_projects as new_max_projects,
    nt.price as upgrade_cost
FROM profiles p
JOIN tiers t ON p.tier = t.name
CROSS JOIN tiers nt
WHERE p.id = auth.uid() 
AND nt.name > p.tier
ORDER BY nt.name;

-- 2. TOOL AVAILABILITY QUERIES
-- =====================================================

-- Get all tools available to current user
SELECT * FROM get_user_available_tools(auth.uid());

-- Check if user can use a specific tool
SELECT can_use_tool(auth.uid(), 1); -- Replace 1 with actual tool_id

-- Get tools by type (manual vs AI)
SELECT 
    type,
    COUNT(*) as tool_count,
    SUM(credit_cost) as total_cost
FROM tools 
WHERE is_active = true
GROUP BY type;

-- 3. PROJECT MANAGEMENT QUERIES
-- =====================================================

-- Get user's projects with edit history
SELECT * FROM get_user_projects_with_history(auth.uid(), 20);

-- Get project details with all edits
SELECT 
    p.name as project_name,
    p.original_image_url,
    p.output_image_url,
    p.created_at as project_created,
    pe.edit_name,
    t.display_name as tool_used,
    pe.parameters,
    pe.credit_cost,
    pe.created_at as edit_created
FROM projects p
LEFT JOIN project_edits pe ON p.id = pe.project_id
LEFT JOIN tools t ON pe.tool_id = t.id
WHERE p.user_id = auth.uid()
ORDER BY p.created_at DESC, pe.created_at DESC;

-- Get project storage usage
SELECT 
    COUNT(*) as total_projects,
    SUM(file_size_bytes) / (1024 * 1024 * 1024.0) as total_storage_gb,
    AVG(file_size_bytes) / (1024 * 1024.0) as avg_file_size_mb
FROM projects 
WHERE user_id = auth.uid();

-- 4. CREDIT MANAGEMENT QUERIES
-- =====================================================

-- Get user's credit summary
SELECT * FROM get_user_credit_summary(auth.uid(), 30);

-- Get credit transaction history
SELECT 
    type,
    amount,
    balance_before,
    balance_after,
    description,
    reference_type,
    created_at
FROM credit_transactions 
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 50;

-- Get credit spending by tool
SELECT 
    t.display_name as tool_name,
    COUNT(*) as usage_count,
    SUM(tul.credit_cost) as total_credits_spent,
    AVG(tul.processing_time_ms) as avg_processing_time
FROM tool_usage_log tul
JOIN tools t ON tul.tool_id = t.id
WHERE tul.user_id = auth.uid()
GROUP BY t.id, t.display_name
ORDER BY total_credits_spent DESC;

-- 5. TOOL USAGE QUERIES
-- =====================================================

-- Use a tool (this will deduct credits and create records)
-- Example: Use brightness adjustment (free manual tool)
SELECT * FROM use_tool(
    auth.uid(),           -- user_id
    1,                    -- tool_id (brightness)
    'project-uuid-here',  -- project_id
    '{"brightness": 0.2}', -- parameters
    'input-image-url',    -- input_image_url
    'Brightness +20%'     -- edit_name
);

-- Get tool usage statistics
SELECT 
    t.display_name,
    t.type,
    COUNT(*) as total_uses,
    SUM(tul.credit_cost) as total_credits_spent,
    AVG(tul.processing_time_ms) as avg_processing_time,
    COUNT(CASE WHEN tul.success = true THEN 1 END) as successful_uses,
    COUNT(CASE WHEN tul.success = false THEN 1 END) as failed_uses
FROM tool_usage_log tul
JOIN tools t ON tul.tool_id = t.id
WHERE tul.user_id = auth.uid()
GROUP BY t.id, t.display_name, t.type
ORDER BY total_uses DESC;

-- 6. ADMINISTRATIVE QUERIES
-- =====================================================

-- Upgrade user tier (admin function)
SELECT upgrade_user_tier(auth.uid(), 'silver');

-- Add credits to user (admin function)
SELECT add_credits(
    auth.uid(),           -- user_id
    100,                  -- amount
    'Admin credit bonus', -- description
    NULL,                 -- reference_id
    'admin_bonus'         -- reference_type
);

-- Get system-wide statistics
SELECT 
    COUNT(*) as total_users,
    COUNT(CASE WHEN tier = 'free_trial' THEN 1 END) as trial_users,
    COUNT(CASE WHEN tier != 'free_trial' THEN 1 END) as paid_users,
    AVG(credits) as avg_credits_per_user,
    SUM(storage_used_gb) as total_storage_used
FROM profiles;

-- 7. PERFORMANCE AND ANALYTICS QUERIES
-- =====================================================

-- Get user activity in last 7 days
SELECT 
    DATE(created_at) as activity_date,
    COUNT(*) as total_actions,
    COUNT(CASE WHEN type = 'spend' THEN 1 END) as credit_spent,
    COUNT(CASE WHEN type = 'earn' THEN 1 END) as credit_earned
FROM credit_transactions 
WHERE user_id = auth.uid()
AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY activity_date DESC;

-- Get most popular tools across all users
SELECT 
    t.display_name,
    t.type,
    COUNT(*) as total_uses,
    AVG(tul.processing_time_ms) as avg_processing_time,
    SUM(tul.credit_cost) as total_credits_spent
FROM tool_usage_log tul
JOIN tools t ON tul.tool_id = t.id
WHERE tul.success = true
GROUP BY t.id, t.display_name, t.type
ORDER BY total_uses DESC
LIMIT 10;

-- 8. STORAGE MANAGEMENT QUERIES
-- =====================================================

-- Check if user is approaching storage limit
SELECT 
    p.storage_used_gb,
    p.max_storage_gb,
    p.max_storage_gb - p.storage_used_gb as remaining_storage_gb,
    CASE 
        WHEN p.storage_used_gb / p.max_storage_gb > 0.9 THEN 'Critical'
        WHEN p.storage_used_gb / p.max_storage_gb > 0.8 THEN 'Warning'
        ELSE 'OK'
    END as storage_status
FROM profiles p
WHERE p.id = auth.uid();

-- Get largest projects by file size
SELECT 
    name,
    file_size_bytes / (1024 * 1024.0) as size_mb,
    created_at
FROM projects 
WHERE user_id = auth.uid()
ORDER BY file_size_bytes DESC
LIMIT 10;

-- 9. TRIAL MANAGEMENT QUERIES
-- =====================================================

-- Get users whose trial is ending soon
SELECT 
    username,
    email,
    trial_ends_at,
    trial_ends_at - NOW() as time_remaining
FROM profiles 
WHERE tier = 'free_trial' 
AND is_trial_active = true
AND trial_ends_at <= NOW() + INTERVAL '3 days'
ORDER BY trial_ends_at;

-- Check trial status
SELECT 
    tier,
    is_trial_active,
    trial_started_at,
    trial_ends_at,
    CASE 
        WHEN tier = 'free_trial' AND NOW() > trial_ends_at THEN 'Trial Expired'
        WHEN tier = 'free_trial' AND NOW() <= trial_ends_at THEN 'Trial Active'
        ELSE 'Paid User'
    END as trial_status
FROM profiles 
WHERE id = auth.uid();

-- 10. ERROR HANDLING AND DEBUGGING QUERIES
-- =====================================================

-- Get failed tool usage attempts
SELECT 
    t.display_name as tool_name,
    tul.error_message,
    tul.parameters,
    tul.created_at
FROM tool_usage_log tul
JOIN tools t ON tul.tool_id = t.id
WHERE tul.user_id = auth.uid()
AND tul.success = false
ORDER BY tul.created_at DESC;

-- Get credit transaction errors
SELECT 
    type,
    amount,
    description,
    created_at
FROM credit_transactions 
WHERE user_id = auth.uid()
AND (amount < 0 OR balance_after < 0)
ORDER BY created_at DESC;
