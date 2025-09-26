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

async function uploadToStorage(userId: string, bytes: Uint8Array): Promise<{ url: string; path: string }> {
  const path = `u/${userId}/${Date.now()}/ai-output.jpg`
  const { error } = await supabase.storage.from('media').upload(path, bytes, {
    contentType: 'image/jpeg',
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
      default:
        throw new Error(`Unknown tool ${job.tool_name}`)
    }

    const uploaded = await uploadToStorage(job.user_id, outputBytes)

    // Update job
    await supabase
      .from('ai_jobs')
      .update({ status: 'completed', result_url: uploaded.url, completed_at: new Date().toISOString() })
      .eq('id', job.id)

    // Touch project output and history
    // 1) update project
    await supabase
      .from('projects')
      .update({ output_image_url: uploaded.url, thumbnail_url: uploaded.url })
      .eq('id', job.project_id)

    // 2) insert project_edits history
    await supabase.from('project_edits').insert({
      project_id: job.project_id,
      edit_name: job.tool_name,
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


