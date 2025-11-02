# Brush Tool Fix - Diagnosis and Solution

## Problem Identified

The brush tool (Mask Edit / Character Edit) was loading forever without completing.

## Root Cause

The brush tool uses a **different API architecture** than all other working tools:

### Working Tools (e.g., Remix, Style, Upscale, Elements, Text Edit)
- Use `https://fal.run/...` endpoints
- **Synchronous** - get immediate response with result
- Simple request/response pattern
- Complete in seconds

### Brush Tool (Character Edit with Mask)
- Uses `https://queue.fal.run/...` endpoint  
- **Asynchronous** - requires job submission then polling
- Complex polling loop (up to 120 attempts over 10 minutes)
- More prone to timeout and error handling issues

## Issues Fixed

### 1. Poor Error Handling in Polling Loop
**Problem:** The polling loop would continue indefinitely on errors, never giving up or reporting issues clearly.

**Fix:** Added:
- Consecutive error tracking (fails after 5 consecutive errors)
- Better error messages at each stage
- Clear timeout message after 120 attempts

### 2. Insufficient Logging
**Problem:** When the job failed or got stuck, there was no way to diagnose why.

**Fix:** Added detailed logging:
- URL prefixes for image, mask, and references
- Status at each polling attempt
- Error details from API responses
- Consecutive error count

### 3. Silent Failures
**Problem:** Network errors or API issues would be caught and silently retried forever.

**Fix:** 
- Now throws clear errors after max consecutive failures
- Better error messages that include HTTP status codes
- JSON stringify for debugging completed jobs with no images

## Changes Made

### File: `supabase/functions/ai-run/index.ts`

#### Enhanced Submission Logging (lines 461-469)
```typescript
console.log('ideogram_character_edit_submitting', { 
  prompt_length: prompt.length, 
  ref_count: refs.length,
  has_mask: !!maskUrl,
  has_image: !!inputUrl,
  mask_url_prefix: maskUrl.substring(0, 50),
  image_url_prefix: inputUrl.substring(0, 50),
  ref_urls_prefixes: refs.map(r => r.substring(0, 50))
})
```

#### Improved Polling Error Handling (lines 499-618)
- Added `consecutiveErrors` counter
- Added `maxConsecutiveErrors = 5` threshold
- Better error messages for status check failures
- Clearer timeout message
- Better result fetching with error handling

## How to Test

1. **Deploy the updated edge function:**
   ```bash
   npx supabase functions deploy ai-run
   ```

2. **Try the brush tool:**
   - Open the editor
   - Go to AI tab
   - Click "Mask Edit" (brush icon)
   - Enter a prompt
   - Select at least 1 reference image
   - Paint a mask
   - Submit

3. **Check logs if it still fails:**
   ```bash
   npx supabase functions logs ai-run
   ```
   
   Look for:
   - `ideogram_character_edit_submitting` - verifies job was submitted
   - `ideogram_character_edit_polling` - verifies polling started
   - `ideogram_character_edit_status` - shows polling progress
   - `ideogram_character_edit_failed` or timeout errors

## Expected Behavior After Fix

- **On Success:** Job completes in 2-5 minutes, image is applied
- **On Failure:** Clear error message appears within 30 seconds to 2 minutes
- **On Timeout:** Clear message after 10 minutes: "Timeout: Character edit job did not complete after 120 polling attempts (~10 minutes)"

## Comparison with Working Tools

| Aspect | Working Tools | Brush Tool (Before) | Brush Tool (After) |
|--------|---------------|---------------------|-------------------|
| API Type | Synchronous | Asynchronous/Queue | Asynchronous/Queue |
| Response Time | 5-30 seconds | 2-10 minutes | 2-10 minutes |
| Error Handling | Simple try/catch | Silent retry loop | Max retry + clear errors |
| Logging | Basic | Minimal | Detailed |
| Timeout Handling | HTTP timeout | None (infinite loop) | 120 attempts + clear message |

## Architecture Notes

The brush tool MUST use the queue API because mask-based character editing is computationally intensive. We cannot change it to use the synchronous API. The fixes ensure:

1. Failures are detected and reported quickly
2. Logs provide debugging information
3. Users get feedback instead of infinite loading

## Next Steps if Still Broken

If the tool still doesn't work after deployment:

1. **Check Supabase logs** for the specific error
2. **Verify FAL_API_KEY** is set correctly
3. **Check if signed URLs** are accessible from fal.ai servers
4. **Verify reference images** are valid and not expired
5. **Test with different reference images** (try fewer/different ones)

The improved logging will now tell you exactly where it's failing.

