import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

type Env = {
  SUPABASE_URL: string
  SUPABASE_SERVICE_ROLE_KEY: string
  FAL_API_KEY?: string
}

const supabase = createClient<Database>(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Minimal DB types used here
type AiJobRow = {
  id: string
  user_id: string
  project_id: string
  tool_name: string
  status: 'queued' | 'running' | 'completed' | 'failed' | 'cancelled'
  payload: Record<string, unknown>
  input_image_url: string | null
  result_url: string | null
  error: string | null
  started_at: string | null
  completed_at: string | null
}

async function fetchBytes(url: string): Promise<Uint8Array> {
  const resp = await fetch(url)
  if (!resp.ok) throw new Error(`HTTP ${resp.status}`)
  const arrayBuf = await resp.arrayBuffer()
  return new Uint8Array(arrayBuf)
}

function detectMime(bytes: Uint8Array): string {
  if (bytes.length >= 4) {
    if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg'
    if (
      bytes[0] === 0x89 &&
      bytes[1] === 0x50 &&
      bytes[2] === 0x4e &&
      bytes[3] === 0x47
    )
      return 'image/png'
  }
  return 'image/jpeg'
}

async function runFalNanoBananaEdit(inputUrl: string, prompt: string): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  const url = 'https://fal.run/fal-ai/nano-banana/edit'
  // Pass the signed Storage URL directly to fal.run to avoid large base64 conversions
  const body = {
    prompt,
    image: inputUrl,
    image_urls: [inputUrl],
    input: { prompt, image: inputUrl, image_urls: [inputUrl] },
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })
  if (!resp.ok) throw new Error(`fal.run HTTP ${resp.status}`)
  const json = await resp.json()
  if (json?.images?.[0]?.url) {
    const img = await fetch(json.images[0].url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  if (typeof json.image === 'string' && json.image.startsWith('data:')) {
    const idx = json.image.indexOf(',')
    const b64data = json.image.slice(idx + 1)
    const binary = atob(b64data)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }
  throw new Error('fal response missing image')
}

// Imagen4: text-to-image generation (no input image required)
async function runFalImagen4Generate(prompt: string): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  const url = 'https://fal.run/fal-ai/imagen4/preview'
  // Provide prompt at root and inside input for broader compatibility
  const body = {
    prompt,
    input: { prompt },
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })

  if (!resp.ok) {
    let details = ''
    try { details = await resp.text() } catch (_) {}
    console.error('imagen4_error', { status: resp.status, details })
    throw new Error(`fal.run HTTP ${resp.status}${details ? `: ${details}` : ''}`)
  }

  const json = await resp.json()
  
  // Try images array first
  if (json?.images?.[0]?.url) {
    const img = await fetch(json.images[0].url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  
  // Fallback: check for image as data URL
  if (typeof json.image === 'string' && json.image.startsWith('data:')) {
    const idx = json.image.indexOf(',')
    const b64data = json.image.slice(idx + 1)
    const binary = atob(b64data)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }
  
  throw new Error('fal imagen4 response missing image')
}

async function runFalStyleTransfer(inputUrl: string, stylePrompt: string): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  const url = 'https://fal.run/fal-ai/image-editing/style-transfer'
  // Provide fields in both root and input for broader compatibility across fal models
  const body = {
    prompt: stylePrompt,
    style_prompt: stylePrompt,
    image: inputUrl,
    image_url: inputUrl,
    image_urls: [inputUrl],
    input: {
      prompt: stylePrompt,
      style_prompt: stylePrompt,
      image: inputUrl,
      image_url: inputUrl,
      image_urls: [inputUrl],
    },
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })
  if (!resp.ok) {
    let details = ''
    try { details = await resp.text() } catch (_) {}
    console.error('style_transfer_error', { status: resp.status, details })
    throw new Error(`fal.run HTTP ${resp.status}${details ? `: ${details}` : ''}`)
  }
  const json = await resp.json()
  if (json?.images?.[0]?.url) {
    const img = await fetch(json.images[0].url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  if (typeof json.image === 'string' && json.image.startsWith('data:')) {
    const idx = json.image.indexOf(',')
    const b64data = json.image.slice(idx + 1)
    const binary = atob(b64data)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }
  throw new Error('fal style transfer response missing image')
}

// SeedVR2 Upscale: upscales an image by a factor (default 2x)
async function runFalSeedVRUpscale(inputUrl: string, upscaleFactor: number): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  const url = 'https://fal.run/fal-ai/seedvr/upscale/image'
  const factor = Math.max(1, Math.min(4, Number.isFinite(upscaleFactor) ? upscaleFactor : 2))

  // Provide fields in both root and input for broader compatibility
  const body = {
    image_url: inputUrl,
    upscale_factor: factor,
    input: {
      image_url: inputUrl,
      upscale_factor: factor,
    },
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })
  if (!resp.ok) {
    let details = ''
    try { details = await resp.text() } catch (_) {}
    console.error('seedvr_upscale_error', { status: resp.status, details })
    throw new Error(`fal.run HTTP ${resp.status}${details ? `: ${details}` : ''}`)
  }
  const json = await resp.json()
  // Prefer { image: { url } } per model schema
  if (json?.image?.url) {
    const img = await fetch(json.image.url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  // Fallbacks similar to other endpoints
  if (json?.images?.[0]?.url) {
    const img = await fetch(json.images[0].url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  if (typeof json.image === 'string' && json.image.startsWith('data:')) {
    const idx = json.image.indexOf(',')
    const b64data = json.image.slice(idx + 1)
    const binary = atob(b64data)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }
  throw new Error('fal seedvr upscaler response missing image')
}

// Elements Remix: nano-banana edit using project image + single reference image
async function runFalElementsRemix(inputUrl: string, prompt: string, referenceUrl: string): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  const url = 'https://fal.run/fal-ai/nano-banana/edit'
  const refs = [referenceUrl].filter((u) => typeof u === 'string' && u.length > 0)
  // Many fal endpoints accept multiple images via image_urls. Provide both the base image and the reference.
  // We also provide fields in both root and input for broader compatibility.
  const body = {
    prompt,
    image: inputUrl,
    image_url: inputUrl,
    image_urls: [inputUrl, ...refs],
    reference_image_urls: refs,
    input: {
      prompt,
      image: inputUrl,
      image_url: inputUrl,
      image_urls: [inputUrl, ...refs],
      reference_image_urls: refs,
    },
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })
  if (!resp.ok) {
    let details = ''
    try { details = await resp.text() } catch (_) {}
    console.error('elements_remix_error', { status: resp.status, details })
    throw new Error(`fal.run HTTP ${resp.status}${details ? `: ${details}` : ''}`)
  }
  const json = await resp.json()
  if (json?.images?.[0]?.url) {
    const img = await fetch(json.images[0].url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  if (typeof json.image === 'string' && json.image.startsWith('data:')) {
    const idx = json.image.indexOf(',')
    const b64data = json.image.slice(idx + 1)
    const binary = atob(b64data)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }
  throw new Error('fal elements remix response missing image')
}

async function runFalCalligrapher(inputUrl: string, textPrompt: string): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  const url = 'https://fal.run/fal-ai/calligrapher'
  const raw = (textPrompt ?? '').trim()
  const needsFormatting = !/\btext\s+is\b/i.test(raw)
  const effectivePrompt = needsFormatting && raw.length > 0 ? `The text is '${raw}'` : raw
  // Provide fields in both root and input for broader compatibility across fal models
  const body = {
    prompt: effectivePrompt,
    image: inputUrl,
    image_url: inputUrl,
    image_urls: [inputUrl],
    source_image_url: inputUrl,
    auto_mask_generation: true,
    input: {
      prompt: effectivePrompt,
      source_image_url: inputUrl,
      image: inputUrl,
      image_url: inputUrl,
      image_urls: [inputUrl],
      auto_mask_generation: true,
    },
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })
  if (!resp.ok) {
    let details = ''
    try { details = await resp.text() } catch (_) {}
    console.error('calligrapher_error', { status: resp.status, details })
    throw new Error(`fal.run HTTP ${resp.status}${details ? `: ${details}` : ''}`)
  }
  const json = await resp.json()
  if (json?.images?.[0]?.url) {
    const img = await fetch(json.images[0].url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  if (typeof json.image === 'string' && json.image.startsWith('data:')) {
    const idx = json.image.indexOf(',')
    const b64data = json.image.slice(idx + 1)
    const binary = atob(b64data)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }
  throw new Error('fal calligrapher response missing image')
}

async function runFalIdeogramReframe(inputUrl: string, width: number, height: number): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  const url = 'https://fal.run/fal-ai/ideogram/v3/reframe'
  const w = Math.max(64, Math.min(4096, Math.floor(width)))
  const h = Math.max(64, Math.min(4096, Math.floor(height)))

  // Provide fields in both root and input for broader compatibility across fal models
  const body = {
    image: inputUrl,
    image_url: inputUrl,
    image_urls: [inputUrl],
    source_image_url: inputUrl,
    // Per model API, prefer image_size preset or object; avoid top-level width/height when image_size provided
    image_size: { width: w, height: h },
    input: {
      image: inputUrl,
      image_url: inputUrl,
      image_urls: [inputUrl],
      source_image_url: inputUrl,
      image_size: { width: w, height: h },
    },
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })
  if (!resp.ok) {
    let details = ''
    try { details = await resp.text() } catch (_) {}
    console.error('ideogram_reframe_error', { status: resp.status, details })
    throw new Error(`fal.run HTTP ${resp.status}${details ? `: ${details}` : ''}`)
  }
  const json = await resp.json()
  if (json?.images?.[0]?.url) {
    const img = await fetch(json.images[0].url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  if (typeof json.image === 'string' && json.image.startsWith('data:')) {
    const idx = json.image.indexOf(',')
    const b64data = json.image.slice(idx + 1)
    const binary = atob(b64data)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }
  throw new Error('fal ideogram reframe response missing image')
}

async function runFalIdeogramCharacterRemix(
  inputUrl: string,
  prompt: string,
  referenceUrls: string[]
): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  const url = 'https://fal.run/fal-ai/ideogram/character/remix'
  const refs = Array.isArray(referenceUrls) ? referenceUrls.filter((u) => typeof u === 'string' && u.length > 0) : []

  // Provide fields in both root and input for broader compatibility across fal models
  const body = {
    prompt,
    image: inputUrl,
    image_url: inputUrl,
    source_image_url: inputUrl,
    reference_image_urls: refs,
    input: {
      prompt,
      image: inputUrl,
      image_url: inputUrl,
      source_image_url: inputUrl,
      reference_image_urls: refs,
    },
  }

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })
  if (!resp.ok) {
    let details = ''
    try { details = await resp.text() } catch (_) {}
    console.error('ideogram_character_remix_error', { status: resp.status, details })
    throw new Error(`fal.run HTTP ${resp.status}${details ? `: ${details}` : ''}`)
  }
  const json = await resp.json()
  if (json?.images?.[0]?.url) {
    const img = await fetch(json.images[0].url)
    if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
    const buf = await img.arrayBuffer()
    return new Uint8Array(buf)
  }
  if (typeof json.image === 'string' && json.image.startsWith('data:')) {
    const idx = json.image.indexOf(',')
    const b64data = json.image.slice(idx + 1)
    const binary = atob(b64data)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  }
  throw new Error('fal ideogram character remix response missing image')
}

// Ideogram Character Edit: Edit characters using mask-based selection
async function runFalIdeogramCharacterEdit(
  inputUrl: string,
  maskUrl: string,
  prompt: string,
  referenceUrls: string[]
): Promise<Uint8Array> {
  const apiKey = Deno.env.get('FAL_API_KEY')
  if (!apiKey) throw new Error('Missing FAL_API_KEY')

  // This endpoint uses queue.fal.run, which requires polling
  const submitUrl = 'https://queue.fal.run/fal-ai/ideogram/character/edit'
  const refs = Array.isArray(referenceUrls) ? referenceUrls.filter((u) => typeof u === 'string' && u.length > 0) : []

  // Step 1: Submit the job
  const body = {
    prompt,
    image_url: inputUrl,
    mask_url: maskUrl,
    reference_image_urls: refs,
  }

  console.log('ideogram_character_edit_submitting', { 
    prompt_length: prompt.length, 
    ref_count: refs.length,
    has_mask: !!maskUrl,
    has_image: !!inputUrl,
    mask_url_prefix: maskUrl.substring(0, 50),
    image_url_prefix: inputUrl.substring(0, 50),
    ref_urls_prefixes: refs.map(r => r.substring(0, 50))
  })

  const submitResp = await fetch(submitUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(body),
  })
  
  if (!submitResp.ok) {
    let details = ''
    try { details = await submitResp.text() } catch (_) {}
    console.error('ideogram_character_edit_submit_error', { 
      status: submitResp.status, 
      details,
      prompt_length: prompt.length,
      ref_count: refs.length
    })
    throw new Error(`fal.run submit HTTP ${submitResp.status}${details ? `: ${details}` : ''}`)
  }

  const submitJson = await submitResp.json()
  console.log('ideogram_character_edit_submitted', { response: submitJson })
  
  // The response should contain status_url or request_id
  const statusUrl = submitJson.status_url || submitJson.statusUrl
  const requestId = submitJson.request_id || submitJson.requestId
  
  if (!statusUrl && !requestId) {
    console.error('ideogram_character_edit_no_status_url', { response: submitJson })
    throw new Error('No status_url or request_id in queue response')
  }

  // Step 2: Poll for status and result
  // Use provided status URL or construct it
  const finalStatusUrl = statusUrl || `https://queue.fal.run/fal-ai/ideogram/character/edit/requests/${requestId}/status`
  console.log('ideogram_character_edit_polling', { status_url: finalStatusUrl, request_id: requestId })
  let attempts = 0
  const maxAttempts = 120 // 10 minutes max with varied intervals
  let consecutiveErrors = 0
  const maxConsecutiveErrors = 5

  while (attempts < maxAttempts) {
    // Dynamic delay: shorter at first, longer later
    const delay = attempts < 6 ? 2000 : attempts < 20 ? 3000 : 5000
    if (attempts > 0) await new Promise(resolve => setTimeout(resolve, delay))
    attempts++

    try {
      const statusResp = await fetch(finalStatusUrl, {
        method: 'GET',
        headers: {
          Authorization: `Key ${apiKey}`,
        },
      })

      if (!statusResp.ok) {
        consecutiveErrors++
        const errorText = await statusResp.text().catch(() => 'Unable to read error')
        console.error('ideogram_character_edit_status_error', { 
          attempt: attempts, 
          status: statusResp.status,
          error: errorText,
          consecutive_errors: consecutiveErrors
        })
        
        // If we get too many consecutive errors, give up
        if (consecutiveErrors >= maxConsecutiveErrors) {
          throw new Error(`Failed to check status after ${consecutiveErrors} consecutive errors: HTTP ${statusResp.status}`)
        }
        continue // Retry on error
      }

      // Reset consecutive error count on successful response
      consecutiveErrors = 0

      const statusJson = await statusResp.json()
      console.log('ideogram_character_edit_status', { 
        attempt: attempts, 
        status: statusJson.status,
        request_id: requestId
      })
      
      if (statusJson.status === 'COMPLETED') {
        // Get the result - try response_url first
        if (statusJson?.response_url) {
          console.log('ideogram_character_edit_fetching_result', { response_url: statusJson.response_url })
          const resultResp = await fetch(statusJson.response_url, {
            headers: {
              Authorization: `Key ${apiKey}`,
            },
          })
          
          if (!resultResp.ok) {
            throw new Error(`Failed to fetch result: HTTP ${resultResp.status}`)
          }
          
          const resultJson = await resultResp.json()
          console.log('ideogram_character_edit_result', { has_images: !!resultJson?.images })
          
          if (resultJson?.images?.[0]?.url) {
            const img = await fetch(resultJson.images[0].url)
            if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
            const buf = await img.arrayBuffer()
            console.log('ideogram_character_edit_success', { image_size: buf.byteLength })
            return new Uint8Array(buf)
          }
        }
        
        // Alternative: result might be in statusJson directly
        if (statusJson?.images?.[0]?.url) {
          const img = await fetch(statusJson.images[0].url)
          if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
          const buf = await img.arrayBuffer()
          console.log('ideogram_character_edit_success_direct', { image_size: buf.byteLength })
          return new Uint8Array(buf)
        }
        
        // Check if result is in data field
        if (statusJson?.data?.images?.[0]?.url) {
          const img = await fetch(statusJson.data.images[0].url)
          if (!img.ok) throw new Error(`image fetch HTTP ${img.status}`)
          const buf = await img.arrayBuffer()
          console.log('ideogram_character_edit_success_data', { image_size: buf.byteLength })
          return new Uint8Array(buf)
        }
        
        console.error('ideogram_character_edit_completed_no_image', { response: JSON.stringify(statusJson) })
        throw new Error('Completed but no image URL found in response')
      } else if (statusJson.status === 'FAILED') {
        const errorMsg = statusJson.error || statusJson.logs || JSON.stringify(statusJson)
        console.error('ideogram_character_edit_failed', { error: errorMsg })
        throw new Error(`Job failed: ${errorMsg}`)
      }
      // Otherwise status is IN_QUEUE or IN_PROGRESS, continue polling
    } catch (error) {
      if (error instanceof Error && (error.message.includes('Job failed') || error.message.includes('Completed but no image') || error.message.includes('consecutive errors'))) {
        throw error // Don't retry on actual failures
      }
      consecutiveErrors++
      console.error('ideogram_character_edit_poll_error', { 
        attempt: attempts, 
        error: error instanceof Error ? error.message : String(error),
        consecutive_errors: consecutiveErrors
      })
      
      // Give up if we hit too many consecutive errors
      if (consecutiveErrors >= maxConsecutiveErrors) {
        throw new Error(`Polling failed after ${consecutiveErrors} consecutive errors: ${error instanceof Error ? error.message : String(error)}`)
      }
      // Continue polling on network/parse errors
    }
  }

  throw new Error(`Timeout: Character edit job did not complete after ${attempts} polling attempts (~10 minutes)`)
}

async function uploadToStorage(userId: string, bytes: Uint8Array, forcePng: boolean = false): Promise<{ url: string; path: string }> {
  // Detect image format: check if it's PNG (supports transparency)
  const isPng = bytes.length >= 4 && 
    bytes[0] === 0x89 && 
    bytes[1] === 0x50 && 
    bytes[2] === 0x4e && 
    bytes[3] === 0x47
  
  // Use PNG format if forced (e.g., for background removal) or if image is already PNG
  const usePng = forcePng || isPng
  const ext = usePng ? 'png' : 'jpg'
  const contentType = usePng ? 'image/png' : 'image/jpeg'
  const path = `u/${userId}/${Date.now()}/ai-output.${ext}`
  
  const { error } = await supabase.storage.from('media').upload(path, bytes, {
    contentType,
    upsert: false,
  })
  if (error) throw error
  const { data, error: signErr } = await supabase.storage.from('media').createSignedUrl(path, 60 * 60 * 24 * 7)
  if (signErr) throw signErr
  return { url: data.signedUrl, path }
}

async function processJob(job: AiJobRow): Promise<void> {
  // Mark running
  await supabase.from('ai_jobs').update({ status: 'running', started_at: new Date().toISOString() }).eq('id', job.id)

  try {
    let outputBytes: Uint8Array
    switch (job.tool_name) {
      case 'nano_banana': {
        const prompt = (job.payload as Record<string, unknown>)['prompt'] as string
        const inputUrl = job.input_image_url as string
        outputBytes = await runFalNanoBananaEdit(inputUrl, prompt)
        break
      }
      case 'seedvr_upscale': {
        const payload = job.payload as Record<string, unknown>
        const inputUrl = job.input_image_url as string
        let factor = Number(payload['upscale_factor'])
        if (!Number.isFinite(factor)) factor = 2
        outputBytes = await runFalSeedVRUpscale(inputUrl, factor)
        break
      }
      case 'style_transfer': {
        const payload = job.payload as Record<string, unknown>
        const inputUrl = job.input_image_url as string
        const stylePrompt = (payload['style_prompt'] as string) ?? (payload['prompt'] as string) ?? ''
        if (!stylePrompt) {
          throw new Error('style_transfer requires style_prompt')
        }
        outputBytes = await runFalStyleTransfer(inputUrl, stylePrompt)
        break
      }
      case 'ideogram_v3_reframe': {
        const payload = job.payload as Record<string, unknown>
        let width = Number(payload['width'])
        let height = Number(payload['height'])
        if (!Number.isFinite(width) || width <= 0) width = 1024
        if (!Number.isFinite(height) || height <= 0) height = 1024
        const inputUrl = job.input_image_url as string
        outputBytes = await runFalIdeogramReframe(inputUrl, Math.floor(width), Math.floor(height))
        break
      }
      case 'remove_background': {
        // For now reuse nano-banana with a default prompt for bg removal
        const prompt = (job.payload as Record<string, unknown>)['prompt'] as string
        const inputUrl = job.input_image_url as string
        outputBytes = await runFalNanoBananaEdit(inputUrl, prompt)
        // Force PNG format for background removal to preserve transparency
        break
      }
      case 'calligrapher': {
        const textPrompt = (job.payload as Record<string, unknown>)['prompt'] as string
        const inputUrl = job.input_image_url as string
        outputBytes = await runFalCalligrapher(inputUrl, textPrompt)
        break
      }
      case 'ideogram_character_remix': {
        const payload = job.payload as Record<string, unknown>
        const inputUrl = job.input_image_url as string
        const prompt = (payload['prompt'] as string) ?? ''
        const refs = Array.isArray(payload['reference_urls'])
          ? (payload['reference_urls'] as unknown[]).filter((u) => typeof u === 'string') as string[]
          : []
        if (!prompt || refs.length === 0) {
          throw new Error('ideogram_character_remix requires prompt and at least one reference url')
        }
        outputBytes = await runFalIdeogramCharacterRemix(inputUrl, prompt, refs)
        break
      }
      case 'elements': {
        const payload = job.payload as Record<string, unknown>
        const inputUrl = job.input_image_url as string
        const prompt = (payload['prompt'] as string) ?? ''
        const referenceUrl = (payload['reference_url'] as string) ?? ''
        if (!prompt || !referenceUrl) {
          throw new Error('elements requires prompt and a reference_url')
        }
        outputBytes = await runFalElementsRemix(inputUrl, prompt, referenceUrl)
        break
      }
      case 'ideogram_character_edit': {
        const payload = job.payload as Record<string, unknown>
        const inputUrl = job.input_image_url as string
        const prompt = (payload['prompt'] as string) ?? ''
        const maskUrl = (payload['mask_url'] as string) ?? ''
        const refs = Array.isArray(payload['reference_urls'])
          ? (payload['reference_urls'] as unknown[]).filter((u) => typeof u === 'string') as string[]
          : []
        if (!prompt || !maskUrl || refs.length === 0) {
          throw new Error('ideogram_character_edit requires prompt, mask_url, and at least one reference_url')
        }
        outputBytes = await runFalIdeogramCharacterEdit(inputUrl, maskUrl, prompt, refs)
        break
      }
      case 'imagen4': {
        // Text-to-image generation - no input image required
        const payload = job.payload as Record<string, unknown>
        const prompt = (payload['prompt'] as string) ?? ''
        if (!prompt) {
          throw new Error('imagen4 requires a prompt')
        }
        outputBytes = await runFalImagen4Generate(prompt)
        break
      }
      default:
        throw new Error(`Unknown tool ${job.tool_name}`)
    }

    // For background removal, force PNG format to preserve transparency
    const forcePng = job.tool_name === 'remove_background'
    const uploaded = await uploadToStorage(job.user_id, outputBytes, forcePng)

    // Update job
    await supabase
      .from('ai_jobs')
      .update({ status: 'completed', result_url: uploaded.url, completed_at: new Date().toISOString() })
      .eq('id', job.id)

    // Touch project output and history
    // 1) update project
    // For imagen4 (text-to-image), also set original_image_url since this is the first image
    const projectUpdate: Record<string, string> = {
      output_image_url: uploaded.url,
      thumbnail_url: uploaded.url,
    }
    if (job.tool_name === 'imagen4') {
      projectUpdate.original_image_url = uploaded.url
    }
    await supabase
      .from('projects')
      .update(projectUpdate)
      .eq('id', job.project_id)

    // 2) insert project_edits history
    // For imagen4 (text-to-image), use a more descriptive edit name
    const editName = job.tool_name === 'imagen4' ? 'AI Generation (Imagen4)' : job.tool_name
    await supabase.from('project_edits').insert({
      project_id: job.project_id,
      edit_name: editName,
      parameters: job.payload,
      input_image_url: job.input_image_url,
      output_image_url: uploaded.url,
      credit_cost: 0,
      status: 'completed',
    })
  } catch (e) {
    await supabase
      .from('ai_jobs')
      .update({ status: 'failed', error: e instanceof Error ? e.message : String(e), completed_at: new Date().toISOString() })
      .eq('id', job.id)
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })

  const { jobId } = await req.json().catch(() => ({}))
  if (!jobId) return new Response(JSON.stringify({ error: 'jobId required' }), { status: 400, headers: { 'Content-Type': 'application/json' } })

  const { data: job, error } = await supabase.from('ai_jobs').select('*').eq('id', jobId).single<AiJobRow>()
  if (error || !job) return new Response(JSON.stringify({ error: 'Job not found' }), { status: 404, headers: { 'Content-Type': 'application/json' } })

  // Run processing in background
  EdgeRuntime.waitUntil(processJob(job))
  return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } })
})

// Dummy type to satisfy generic; you can replace with generated types later
type Database = any


