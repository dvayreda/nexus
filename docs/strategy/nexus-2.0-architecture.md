# NEXUS 2.0 ARCHITECTURE VISION

**Document Version:** 1.0
**Created:** 2025-11-18
**Author:** AI Architecture Analysis
**Status:** Strategic Proposal

---

## EXECUTIVE SUMMARY

### Current State: Nexus 1.0

**What We Have:**
- **Platform:** Self-hosted on Raspberry Pi 4 (4GB RAM, 2GB swap)
- **Purpose:** Automated Instagram carousel generation for FactsMind brand
- **Stack:** Docker (6 containers), n8n orchestration, PostgreSQL, Redis
- **AI:** Groq (facts) + Gemini (content + images)
- **Output:** 5-slide carousels, 1-3 posts/day
- **Performance:** ~60 seconds per carousel, fully automated
- **Status:** Production-ready, generating daily content

**Key Strengths:**
- ✅ **Working System:** Generates quality content 24/7
- ✅ **Low Cost:** ~$30-40/month in AI APIs, $15W power
- ✅ **Full Control:** Self-hosted, no vendor lock-in
- ✅ **Proven:** Production-tested, handles real workload
- ✅ **Documented:** 2,666 lines of documentation

**Critical Limitations:**
- ❌ **Single Point of Failure:** One Pi, no redundancy
- ❌ **Performance Ceiling:** Can't parallelize beyond 4 cores
- ❌ **Scaling Limits:** Memory-constrained (4GB total)
- ❌ **Single Brand:** Hardcoded for FactsMind only
- ❌ **Manual Deployment:** No CI/CD, SSH-based updates
- ❌ **Geographic Lock:** Pi at home, no global deployment
- ❌ **Instagram Only:** Can't easily add YouTube/TikTok

### Future Vision: Nexus 2.0

**What Nexus 2.0 Should Be:**

A **production-grade, multi-tenant AI content automation platform** capable of:
- ✨ **Multi-Brand:** Run 10+ content brands simultaneously
- ✨ **Multi-Platform:** Instagram, YouTube Shorts, TikTok, Twitter, blogs
- ✨ **Multi-Region:** Deploy globally with <100ms latency
- ✨ **Auto-Scaling:** Handle 1 post/day → 1000 posts/day seamlessly
- ✨ **Team Collaboration:** Multiple users, roles, permissions
- ✨ **SaaS-Ready:** White-label, billing, admin dashboard
- ✨ **99.9% Uptime:** High availability with automated failover
- ✨ **Advanced AI:** Multi-model ensemble, RAG, quality validation

**Strategic Goals:**
1. **Performance:** 60s → 10s per carousel (6x faster)
2. **Cost Efficiency:** 50% lower cost per post (economies of scale)
3. **Reliability:** 99% → 99.9% uptime (eliminate Pi as SPOF)
4. **Flexibility:** Support any content format, any platform
5. **Monetization:** Enable SaaS/agency/consulting business models

### Key Improvements Overview

| Category | Current (Nexus 1.0) | Target (Nexus 2.0) | Improvement |
|----------|---------------------|-------------------|-------------|
| **Infrastructure** | Single Pi | Multi-region cloud | 99.9% uptime |
| **Performance** | 60s/carousel | 10s/carousel | 6x faster |
| **Capacity** | 3 posts/day | 1000+ posts/day | 300x scale |
| **Brands** | 1 (FactsMind) | Unlimited | Multi-tenant |
| **Platforms** | Instagram only | 5+ platforms | Universal |
| **Deployment** | Manual SSH | CI/CD automated | Zero-touch |
| **Cost/Post** | $0.50 | $0.10 | 80% reduction |
| **Team** | 1 person | 10+ collaborators | Team-ready |

### Migration Complexity Rating

**Overall Complexity:** 🟠 **MEDIUM-HIGH** (6-8 weeks full-time)

**Breakdown:**
- Infrastructure migration: 🟢 **LOW** (existing Docker knowledge transfers)
- Code refactoring: 🟡 **MEDIUM** (multi-tenancy, config management)
- Data migration: 🟢 **LOW** (PostgreSQL export/import)
- Testing & validation: 🔴 **HIGH** (ensure feature parity)
- Cutover & rollback plan: 🟡 **MEDIUM** (parallel run required)

**Risk Level:** 🟡 **MEDIUM** - Production system, revenue-generating

**Recommended Approach:** Phased migration with parallel run (detailed in Section 7)

---

## ARCHITECTURE OPTIONS ANALYSIS

We evaluated three distinct approaches for Nexus 2.0. Each has different trade-offs in cost, complexity, scalability, and time-to-market.

### Option A: Enhanced Pi (Evolutionary)

**Concept:** Optimize the current Raspberry Pi setup to its maximum potential before considering migration.

#### Architecture

```
┌─────────────────────────────────────────────────┐
│ HARDWARE UPGRADES                               │
├─────────────────────────────────────────────────┤
│ • Raspberry Pi 5 (8GB RAM) - $80               │
│ • NVMe SSD via PCIe - $60                      │
│ • Backup Pi for failover - $140                │
│ • UPS for power redundancy - $100              │
│ Total Hardware: ~$380                          │
└─────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────┐
│ SOFTWARE OPTIMIZATIONS                          │
├─────────────────────────────────────────────────┤
│ • Parallel processing (4x image generation)    │
│ • Redis caching layer                          │
│ • PostgreSQL query optimization                │
│ • Docker resource limits tuning                │
│ • Swap optimization (4GB zram)                 │
└─────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────┐
│ CLOUD HYBRID SERVICES                          │
├─────────────────────────────────────────────────┤
│ • S3 for output storage (offload disk)        │
│ • CloudFlare for CDN/caching                   │
│ • Tailscale for secure remote access          │
│ • Uptime monitoring (BetterStack)             │
└─────────────────────────────────────────────────┘
```

#### Technical Implementation

**1. Hardware Upgrade Path:**
```bash
# Raspberry Pi 5 advantages over Pi 4:
- 2.4GHz quad-core ARM Cortex-A76 (vs 1.8GHz A72)
- 8GB RAM option (vs 4GB max)
- PCIe 2.0 for NVMe SSD (10x faster than USB3)
- Dual 4K display support (future video editing)
- Improved thermals (better sustained performance)

# Cost: $80 (Pi 5 8GB) + $60 (NVMe SSD) = $140
```

**2. Failover Configuration:**
```yaml
# docker-compose-failover.yml (on backup Pi)
services:
  n8n:
    image: your-registry/nexus-n8n:latest
    restart: unless-stopped
    environment:
      DB_POSTGRESDB_HOST: primary-pi.tailscale  # Connect to primary DB
      FAILOVER_MODE: "true"
      HEALTH_CHECK_URL: http://primary-pi:5678/healthz

  # Automated failover script
  failover-monitor:
    image: alpine:latest
    command: |
      while true; do
        if ! curl -f http://primary-pi:5678/healthz; then
          echo "Primary down, taking over..."
          docker-compose -f docker-compose-primary.yml up -d
        fi
        sleep 30
      done
```

**3. Performance Optimizations:**
```python
# Parallel image generation (currently sequential)
# Before: 40s for 4 images (10s each)
# After: 10s for 4 images (parallel)

from concurrent.futures import ThreadPoolExecutor

def generate_carousel_parallel(slides):
    with ThreadPoolExecutor(max_workers=4) as executor:
        # Generate all 4 images simultaneously
        futures = [
            executor.submit(gemini.generate_image, slide['prompt'])
            for slide in slides[0:4]  # Slides 1-4 need images
        ]

        images = [f.result() for f in futures]

    return images

# Saves 30 seconds per carousel!
```

**4. Caching Layer:**
```python
# Redis caching for repeated content
import redis
import hashlib

cache = redis.Redis(host='redis', port=6379)

def get_cached_carousel(fact_hash):
    cached = cache.get(f"carousel:{fact_hash}")
    if cached:
        return json.loads(cached)
    return None

def cache_carousel(fact_hash, carousel_data):
    cache.setex(
        f"carousel:{fact_hash}",
        86400,  # 24 hour TTL
        json.dumps(carousel_data)
    )

# Avoids re-generating similar facts
# Saves ~$0.30 per cached hit
```

#### Pros

✅ **Low Migration Risk** - Incremental improvements, no big bang
✅ **Minimal Downtime** - Upgrade in-place, <1 hour offline
✅ **Cost Effective** - $380 hardware + $10/month cloud services
✅ **Familiar Environment** - Same stack, same deployment
✅ **Quick Wins** - Parallel processing = immediate 6x speedup
✅ **No Code Rewrite** - Optimization, not refactoring
✅ **Keep Self-Hosted** - No vendor lock-in

#### Cons

❌ **Hard Scaling Ceiling** - 8GB RAM max, 4 cores max
❌ **Single Geographic Location** - Can't serve global users <100ms
❌ **Manual Failover** - Requires intervention if primary dies
❌ **Limited Multi-Tenancy** - Pi can't run 10+ brands efficiently
❌ **No Team Collaboration** - Still single-user system
❌ **Physical Dependency** - Home internet, power outages
❌ **Future Bottleneck** - Will outgrow Pi within 6-12 months if scaling

#### Cost Analysis

**One-Time Costs:**
- Raspberry Pi 5 (8GB): $80
- NVMe SSD (512GB): $60
- Backup Pi 4 (existing): $0
- UPS (CyberPower 600VA): $100
- **Total:** $240

**Monthly Costs:**
- AI APIs: $30-40 (unchanged)
- S3 storage: $5 (100GB)
- CloudFlare: $0 (free tier)
- Monitoring: $10 (BetterStack)
- Power: $3 (15W × 2 Pis)
- **Total:** ~$50/month (+$10 from current)

**ROI:** $240 upfront + $10/month ongoing = Break-even in 24 months

#### Performance Characteristics

- **Generation Time:** 60s → 15s (4x faster via parallelization)
- **Throughput:** 3 posts/day → 20 posts/day (7x capacity)
- **Latency:** No change (local processing)
- **Reliability:** 95% → 98% uptime (UPS + failover)
- **Scaling:** Linear until 8GB RAM exhausted (~20-30 posts/day max)

#### Verdict

**Best For:**
- Conservative approach
- Budget-constrained ($240 vs $500+)
- Learning/experimentation phase
- 1-2 brands, <20 posts/day

**Avoid If:**
- Need multi-region deployment
- Want to scale to 10+ brands
- Building SaaS product
- Team collaboration required

---

### Option B: Hybrid Pi + Cloud (Pragmatic)

**Concept:** Keep Pi as orchestration hub, offload heavy workloads to cloud functions. Best of both worlds.

#### Architecture

```
┌──────────────────────────────────────────────────────────┐
│ ON-PREMISES (Raspberry Pi)                               │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ n8n          │  │ PostgreSQL   │  │ Redis        │  │
│  │ (Orchestration)│ │ (Metadata)  │  │ (Queue)      │  │
│  │ Lightweight  │  │ Small DB     │  │ Cache only   │  │
│  └──────┬───────┘  └──────────────┘  └──────────────┘  │
│         │                                                 │
└─────────┼─────────────────────────────────────────────────┘
          │ Triggers cloud functions ↓
┌─────────┼─────────────────────────────────────────────────┐
│ CLOUD SERVICES                                            │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌────────────────────────────────────────────┐         │
│  │ AWS Lambda / Cloudflare Workers            │         │
│  │ • Image generation (Gemini API)            │         │
│  │ • Carousel composition (Python + Pillow)   │         │
│  │ • Video rendering (FFmpeg for Shorts)      │         │
│  │ • Parallel execution (100+ concurrent)     │         │
│  └────────────────────────────────────────────┘         │
│                                                           │
│  ┌────────────────────────────────────────────┐         │
│  │ S3-Compatible Storage (R2/S3)              │         │
│  │ • Generated images                         │         │
│  │ • Final carousels                          │         │
│  │ • Template assets                          │         │
│  │ • CDN delivery                             │         │
│  └────────────────────────────────────────────┘         │
│                                                           │
│  ┌────────────────────────────────────────────┐         │
│  │ Managed PostgreSQL (optional)              │         │
│  │ • Supabase / PlanetScale / Neon            │         │
│  │ • Automatic backups                        │         │
│  │ • Global replication                       │         │
│  └────────────────────────────────────────────┘         │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

#### Technical Implementation

**1. Serverless Functions for Heavy Workloads:**

```python
# deploy/lambda/generate_carousel.py
# AWS Lambda function (2GB RAM, 30s timeout)

import json
from PIL import Image, ImageDraw, ImageFont
import boto3
import requests

s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Event: {
        "slide_num": 1,
        "slide_type": "hook",
        "title": "...",
        "subtitle": "...",
        "image_url": "https://..."  # Generated by Gemini
    }
    """

    # Download template from S3
    template_key = f"templates/template_{event['slide_type']}.png"
    s3.download_file('nexus-assets', template_key, '/tmp/template.png')
    template = Image.open('/tmp/template.png')

    # Download generated image
    if event.get('image_url'):
        img_data = requests.get(event['image_url']).content
        with open('/tmp/generated.png', 'wb') as f:
            f.write(img_data)
        gen_img = Image.open('/tmp/generated.png')

        # Paste and composite (same logic as composite.py)
        # ... composition code ...

    # Save to S3
    output_key = f"outputs/{event['carousel_id']}/slide_{event['slide_num']}.png"
    template.save('/tmp/output.png')
    s3.upload_file('/tmp/output.png', 'nexus-outputs', output_key)

    return {
        'statusCode': 200,
        'body': json.dumps({
            'output_url': f"https://cdn.nexus.com/{output_key}"
        })
    }
```

**2. n8n Integration (Hybrid Orchestration):**

```javascript
// n8n HTTP Request node: Call Lambda
{
  "method": "POST",
  "url": "https://your-lambda-url.amazonaws.com/generate-carousel",
  "body": {
    "slide_num": "{{ $json.slide_num }}",
    "slide_type": "{{ $json.slide_type }}",
    "title": "{{ $json.title }}",
    "subtitle": "{{ $json.subtitle }}",
    "image_url": "{{ $json.image_url }}"
  }
}

// Response: { "output_url": "https://..." }
// n8n continues to next slide
```

**3. Cloudflare Workers (Cheaper Alternative):**

```javascript
// workers/carousel-generator.js
// Runs on Cloudflare's edge network

export default {
  async fetch(request, env, ctx) {
    const { slide_num, title, subtitle, image_url } = await request.json();

    // Generate carousel using Cloudflare's image processing
    const response = await fetch(image_url);
    const imageBuffer = await response.arrayBuffer();

    // Use Cloudflare Images API for composition
    const output = await env.CF_IMAGES.transform(imageBuffer, {
      width: 1080,
      height: 1350,
      fit: 'cover',
      // Add text overlay via CF Images (limited vs Pillow)
    });

    // Store in R2 (S3-compatible, cheaper)
    await env.R2_BUCKET.put(
      `outputs/slide_${slide_num}.png`,
      output
    );

    return new Response(JSON.stringify({ success: true }));
  }
};

// Cost: $5/month for 10M requests (vs Lambda $20+)
```

**4. Data Flow:**

```
1. n8n (Pi) triggers workflow
   ↓
2. Groq API (cloud) - generate fact
   ↓
3. Gemini API (cloud) - expand content + generate images
   ↓
4. n8n stores images URLs in PostgreSQL (Pi)
   ↓
5. n8n triggers Lambda (cloud) × 5 in parallel
   ↓
6. Lambda composites slides, uploads to S3
   ↓
7. n8n retrieves S3 URLs, sends to Telegram
   ↓
8. Human approves
   ↓
9. n8n triggers Instagram API (cloud)
```

#### Pros

✅ **Best Performance** - Cloud functions = unlimited parallelization
✅ **Cost Efficient** - Pay per execution, not per hour
✅ **Global Distribution** - CloudFlare = <50ms worldwide
✅ **Keep Pi Benefits** - Self-hosted orchestration, full control
✅ **Easier Scaling** - Add more Lambda concurrency = instant scale
✅ **Managed Services** - S3, Lambda auto-scale and backup
✅ **Incremental Migration** - Move workloads one at a time
✅ **Future-Proof** - Can migrate fully to cloud later

#### Cons

❌ **Vendor Lock-In** - Dependent on AWS/Cloudflare
❌ **Complexity** - Managing both Pi and cloud infrastructure
❌ **Network Dependency** - Pi must have reliable internet
❌ **Debugging Harder** - Distributed system, more moving parts
❌ **Cost Unpredictability** - Lambda costs vary with usage
❌ **Cold Starts** - First Lambda execution slower (1-2s)
❌ **Limited Local Testing** - Can't fully test cloud functions locally

#### Cost Analysis

**One-Time Costs:**
- Raspberry Pi (keep existing): $0
- Lambda deployment setup: $0 (free tier)
- **Total:** $0

**Monthly Costs:**
- AI APIs: $30-40 (unchanged)
- AWS Lambda: $15 (1M executions/month)
  - 100 posts/day × 30 days × 5 slides = 15K executions
  - $0.20 per 1M requests + $0.00001667 per GB-second
  - Estimate: $15/month at scale
- S3 storage: $10 (500GB outputs)
- CloudFront CDN: $5 (100GB bandwidth)
- RDS PostgreSQL (optional): $25 (t4g.micro)
- **Total:** $85-130/month (vs $40 current)

**Cost Per Carousel:**
- Current: $0.50 (API costs + power)
- Hybrid: $0.40 (economies of scale, cheaper per unit)

**ROI:** Higher monthly cost BUT enables 10x more volume at same CPU

#### Performance Characteristics

- **Generation Time:** 60s → 10s (6x faster via parallel Lambda)
- **Throughput:** 3 posts/day → 500+ posts/day (Lambda scales)
- **Latency:** <100ms global (CloudFlare edge)
- **Reliability:** 99.5% (Pi orchestration + cloud redundancy)
- **Scaling:** Near-infinite (Lambda concurrency limit: 1000)

#### Scaling Roadmap

**Phase 1 (Current → 10 posts/day):**
- Keep all processing on Pi
- Add S3 for storage only
- **Cost:** +$5/month

**Phase 2 (10 → 50 posts/day):**
- Move image generation to Lambda
- Keep composition on Pi
- **Cost:** +$20/month

**Phase 3 (50 → 500 posts/day):**
- Move composition to Lambda
- Pi becomes orchestration only
- **Cost:** +$60/month

**Phase 4 (500+ posts/day):**
- Consider full cloud migration (Option C)

#### Verdict

**Best For:**
- Growth-oriented (plan to scale 10x)
- Want global performance
- Building SaaS or agency
- Need team collaboration
- Multi-brand support

**Avoid If:**
- Want to stay fully self-hosted
- Budget <$100/month
- Don't need >20 posts/day
- Prefer simplicity over scalability

---

### Option C: Full Cloud Migration (Transformational)

**Concept:** Rebuild Nexus as cloud-native platform using modern SaaS architecture. Maximum scalability and reliability.

#### Architecture

```
┌────────────────────────────────────────────────────────────┐
│ GLOBAL CDN & EDGE (Cloudflare)                            │
│ • DDoS protection                                         │
│ • WAF (Web Application Firewall)                         │
│ • Edge caching                                            │
│ • <50ms latency worldwide                                │
└────────────────┬───────────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────────┐
│ APPLICATION LAYER (Kubernetes / Fly.io / Railway)        │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Web App      │  │ API Server   │  │ Admin Panel  │   │
│  │ (Next.js)    │  │ (FastAPI)    │  │ (React)      │   │
│  │ User facing  │  │ REST + WS    │  │ Management   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Workflow Eng │  │ Job Queue    │  │ Auth Service │   │
│  │ (Temporal)   │  │ (BullMQ)     │  │ (Clerk/Auth0)│   │
│  │ Orchestration│  │ Background   │  │ Multi-tenant │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└────────────────────────────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────────┐
│ DATA LAYER                                                │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ PostgreSQL   │  │ Redis        │  │ S3/R2        │   │
│  │ (Supabase)   │  │ (Upstash)    │  │ (Objects)    │   │
│  │ Multi-tenant │  │ Cache+Queue  │  │ Assets       │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐                     │
│  │ Vector DB    │  │ Analytics    │                     │
│  │ (Pinecone)   │  │ (PostHog)    │                     │
│  │ RAG/Search   │  │ Metrics      │                     │
│  └──────────────┘  └──────────────┘                     │
└────────────────────────────────────────────────────────────┘
```

#### Technical Stack

**Frontend:**
- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- Shadcn/ui components
- Vercel deployment

**Backend:**
- FastAPI (Python) - REST API
- Temporal - Workflow orchestration (replacing n8n)
- BullMQ - Job queue
- Clerk/Auth0 - Authentication
- Stripe - Billing

**Data:**
- Supabase (PostgreSQL + Auth + Realtime)
- Upstash Redis (serverless)
- Cloudflare R2 (S3-compatible storage)
- Pinecone (vector database for RAG)

**Observability:**
- Sentry - Error tracking
- PostHog - Product analytics
- BetterStack - Uptime monitoring
- Grafana Cloud - Metrics/logs

**Infrastructure:**
- Fly.io / Railway (app hosting)
- GitHub Actions (CI/CD)
- Terraform (IaC)

#### Multi-Tenant Data Model

```sql
-- Multi-tenant schema design
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,  -- nexus-demo.app
    plan TEXT NOT NULL,  -- free, pro, enterprise
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id),
    name TEXT NOT NULL,  -- FactsMind, TechDaily, etc
    platforms JSONB NOT NULL,  -- {instagram: {...}, tiktok: {...}}
    ai_config JSONB NOT NULL,  -- Model preferences, prompts
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE content_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    platform TEXT NOT NULL,  -- instagram, tiktok, youtube
    status TEXT NOT NULL,  -- draft, approved, published, failed
    content JSONB NOT NULL,  -- Slides, captions, hashtags
    assets TEXT[] NOT NULL,  -- S3 URLs for images/videos
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_posts_brand_status ON content_posts(brand_id, status);
CREATE INDEX idx_posts_published ON content_posts(published_at DESC);

-- Row-Level Security (RLS) for multi-tenancy
ALTER TABLE content_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON content_posts
    USING (brand_id IN (
        SELECT id FROM brands WHERE organization_id = current_setting('app.current_org_id')::UUID
    ));
```

#### Workflow Engine Migration

**Current (n8n):**
- Visual workflow editor
- 608-line JSON workflow
- Manual deployment

**Proposed (Temporal):**
```python
# workflows/carousel_generation.py
from temporalio import workflow, activity
from datetime import timedelta

@workflow.defn
class CarouselGenerationWorkflow:
    @workflow.run
    async def run(self, brand_id: str, topic: str) -> dict:
        # Step 1: Generate fact
        fact = await workflow.execute_activity(
            generate_fact,
            args=[topic],
            start_to_close_timeout=timedelta(seconds=30)
        )

        # Step 2: Expand content
        carousel_data = await workflow.execute_activity(
            expand_to_carousel,
            args=[fact, brand_id],
            start_to_close_timeout=timedelta(seconds=60)
        )

        # Step 3: Generate images (parallel)
        image_tasks = [
            workflow.execute_activity(
                generate_image,
                args=[slide['prompt']],
                start_to_close_timeout=timedelta(seconds=30)
            )
            for slide in carousel_data['slides'][:4]
        ]
        images = await asyncio.gather(*image_tasks)

        # Step 4: Compose slides (parallel)
        slide_tasks = [
            workflow.execute_activity(
                compose_slide,
                args=[slide, image],
                start_to_close_timeout=timedelta(seconds=10)
            )
            for slide, image in zip(carousel_data['slides'], images)
        ]
        final_slides = await asyncio.gather(*slide_tasks)

        # Step 5: Quality validation (AI)
        approved = await workflow.execute_activity(
            validate_quality,
            args=[carousel_data, final_slides],
            start_to_close_timeout=timedelta(seconds=20)
        )

        if not approved:
            raise Exception("Quality validation failed")

        # Step 6: Store in DB + S3
        post_id = await workflow.execute_activity(
            save_post,
            args=[brand_id, carousel_data, final_slides],
            start_to_close_timeout=timedelta(seconds=10)
        )

        return {"post_id": post_id, "status": "ready_for_approval"}

# Activities are pure functions, testable
@activity.defn
async def generate_fact(topic: str) -> dict:
    groq_client = GroqClient()
    return groq_client.generate_fact(topic)

# Temporal provides:
# - Automatic retries
# - Timeout handling
# - Distributed execution
# - Versioning
# - Observability
```

**Why Temporal over n8n:**
- ✅ Code-first (version controlled)
- ✅ Type-safe (TypeScript/Python)
- ✅ Testable (unit + integration tests)
- ✅ Scalable (distributed execution)
- ✅ Observable (built-in tracing)
- ✅ Reliable (durable execution, automatic retries)

#### Pros

✅ **Maximum Scalability** - 1 post/day → 10,000 posts/day
✅ **Global Performance** - <50ms latency worldwide
✅ **99.9% Uptime** - Multi-region, auto-failover
✅ **Team Collaboration** - Multi-user, roles, permissions
✅ **SaaS-Ready** - Billing, multi-tenancy, white-label
✅ **Modern Stack** - Maintainable, hireable developers
✅ **Observable** - Full monitoring, tracing, logging
✅ **Secure** - SOC2 ready, RLS, encryption at rest

#### Cons

❌ **High Complexity** - 10x more components than Pi
❌ **Expensive** - $300-500/month minimum (vs $40)
❌ **Time to Build** - 6-8 weeks full-time (vs 1 week)
❌ **Vendor Lock-In** - Dependent on 10+ services
❌ **Learning Curve** - New tech stack (Temporal, Supabase, etc)
❌ **Overkill for Hobby** - If just running FactsMind, too much
❌ **Ongoing Maintenance** - More infrastructure to manage

#### Cost Analysis

**Development Costs:**
- Frontend (Next.js): 2 weeks
- Backend (FastAPI): 2 weeks
- Temporal workflows: 1 week
- Multi-tenancy: 1 week
- Billing integration: 1 week
- Testing + deployment: 1 week
- **Total:** 8 weeks × $5000/week = $40,000 (if hiring)
- **Or:** 3-4 months solo development

**Monthly Costs (at scale):**
- Fly.io (2 instances): $40
- Supabase Pro: $25
- Upstash Redis: $10
- Cloudflare R2: $15 (1TB)
- Temporal Cloud: $200 (managed)
- Sentry: $26
- PostHog: $20
- BetterStack: $10
- Clerk Auth: $25
- Stripe: 2.9% + $0.30 per transaction
- **Total:** ~$371/month base + variable costs

**Cost Per Post (at 1000 posts/day):**
- Infrastructure: $371 / 30,000 = $0.012
- AI APIs: $0.10 (economies of scale)
- **Total:** $0.11 per post (vs $0.50 current)

**Break-Even:** Need ~50 paying customers at $20/month to cover costs

#### Performance Characteristics

- **Generation Time:** 60s → 8s (parallel execution + optimizations)
- **Throughput:** 3 posts/day → 10,000+ posts/day (cloud scale)
- **Latency:** <50ms anywhere (global CDN)
- **Reliability:** 99.9% uptime (multi-region, auto-failover)
- **Scaling:** Essentially unlimited (cloud resources)

#### Verdict

**Best For:**
- SaaS product vision
- Funding secured ($50K+)
- Team of 2-3 developers
- Targeting 100+ customers
- Multi-brand agencies
- Enterprise clients

**Avoid If:**
- Solo hobbyist
- Budget <$500/month
- Just running 1-2 brands
- No developer team
- Want simplicity

---

## DECISION MATRIX

### Comparison Table

| Criteria | Option A: Enhanced Pi | Option B: Hybrid | Option C: Full Cloud |
|----------|----------------------|------------------|---------------------|
| **Upfront Cost** | $240 | $0 | $40,000 |
| **Monthly Cost** | $50 | $85-130 | $371+ |
| **Migration Time** | 1 week | 2-3 weeks | 8 weeks |
| **Complexity** | 🟢 Low | 🟡 Medium | 🔴 High |
| **Performance** | 15s/post | 10s/post | 8s/post |
| **Max Throughput** | 20/day | 500/day | 10,000/day |
| **Reliability** | 98% | 99.5% | 99.9% |
| **Team Collab** | ❌ No | ⚠️ Limited | ✅ Yes |
| **Multi-Tenant** | ❌ No | ⚠️ Possible | ✅ Native |
| **SaaS Ready** | ❌ No | ⚠️ Requires work | ✅ Yes |
| **Vendor Lock-In** | 🟢 None | 🟡 Medium | 🔴 High |
| **Future Scaling** | 🔴 Limited | 🟡 Good | 🟢 Unlimited |

### Recommendation by Use Case

**If you want to:**
- **Just optimize FactsMind** → **Option A** (Enhanced Pi)
- **Test SaaS concept** → **Option B** (Hybrid)
- **Build serious business** → **Option C** (Full Cloud)

**If your budget is:**
- **<$100/month** → **Option A**
- **$100-300/month** → **Option B**
- **$500+/month + dev time** → **Option C**

**If your timeline is:**
- **1 week** → **Option A**
- **2-4 weeks** → **Option B**
- **2-3 months** → **Option C**

---

## NEXT SECTIONS PREVIEW

The following sections will deep-dive into:

**Section 3:** Detailed architecture for recommended option (Option B: Hybrid)
**Section 4:** Alternative tech stack comparisons with decision matrices
**Section 5:** Multi-brand architecture patterns
**Section 6:** Content type expansion (video, blogs, etc)
**Section 7:** Step-by-step migration strategy
**Section 8:** Future-proofing and long-term vision

---

## SECTION 3: RECOMMENDED ARCHITECTURE - HYBRID PI + CLOUD (DETAILED IMPLEMENTATION)

**Decision:** We're proceeding with **Option B (Hybrid Pi + Cloud)** for the following strategic reasons:
- ✅ **Pragmatic:** Leverages existing Pi investment while gaining cloud benefits
- ✅ **Incremental:** Migrate workloads one at a time, low risk
- ✅ **Cost-Effective:** $85-130/month vs $371+ for full cloud
- ✅ **Scalable:** Can grow from 3 posts/day to 500+ posts/day
- ✅ **Reversible:** Can roll back to Pi-only or migrate fully to cloud later

This section provides a complete technical blueprint for implementation.

---

### 3.1 System Architecture Diagram (Detailed)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ USER INTERFACE LAYER                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Telegram Bot]  ←─→  [n8n Webhooks]  ←─→  [Admin Dashboard (Future)]    │
│  • Manual approve               • HTTP endpoints           • Web UI        │
│  • View previews                • Trigger workflows        • Brand mgmt    │
│  • Schedule posts               • Status updates           • Analytics     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↕
┌─────────────────────────────────────────────────────────────────────────────┐
│ ON-PREMISES: RASPBERRY PI 4 (Orchestration Hub)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ n8n (Workflow Orchestration) - Port 5678                          │   │
│  │ ─────────────────────────────────────────────────────────────────  │   │
│  │ • Cron triggers (daily at 9 AM, 3 PM, 9 PM)                      │   │
│  │ • Webhook receivers (manual triggers, approvals)                  │   │
│  │ • HTTP request nodes (call cloud functions)                       │   │
│  │ • Conditional logic (quality checks, retries)                     │   │
│  │ • State management (track workflow progress)                      │   │
│  │ Resource: ~500MB RAM, 0.5 CPU core                               │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ PostgreSQL 15 (Metadata Store) - Port 5432                        │   │
│  │ ─────────────────────────────────────────────────────────────────  │   │
│  │ • Workflow execution history (n8n)                                │   │
│  │ • Carousel metadata (titles, captions, hashtags)                  │   │
│  │ • Brand configurations (FactsMind settings)                       │   │
│  │ • Publishing schedule and status                                  │   │
│  │ • Asset URLs (references to S3 objects)                           │   │
│  │ Size: ~2GB database, growing ~100MB/month                        │   │
│  │ Resource: ~300MB RAM, 0.2 CPU core                               │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ Redis 7 (Cache + Queue) - Port 6379                               │   │
│  │ ─────────────────────────────────────────────────────────────────  │   │
│  │ • Job queue for cloud function invocations                        │   │
│  │ • Response caching (Groq/Gemini API responses)                    │   │
│  │ • Rate limiting (API quotas)                                      │   │
│  │ • Session storage (Telegram bot state)                            │   │
│  │ Resource: ~150MB RAM, 0.1 CPU core                               │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │ Nginx (Reverse Proxy) - Port 80/443                               │   │
│  │ ─────────────────────────────────────────────────────────────────  │   │
│  │ • SSL termination (Let's Encrypt certs)                           │   │
│  │ • Load balancing (future: multiple n8n instances)                 │   │
│  │ • Access logs for audit trail                                     │   │
│  │ Resource: ~50MB RAM, 0.1 CPU core                                │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Total Pi Resource Usage: ~1GB RAM, 1 CPU core (25% capacity)             │
│  Remaining: 3GB RAM, 3 CPU cores for future expansion                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↕
                        [SECURE VPN: Tailscale Mesh Network]
                        • Zero-trust networking
                        • Pi accessible from anywhere
                        • End-to-end encryption
                                    ↕
┌─────────────────────────────────────────────────────────────────────────────┐
│ CLOUD LAYER: AWS / Cloudflare (Compute + Storage)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ COMPUTE: Serverless Functions (AWS Lambda)                      │      │
│  │ ──────────────────────────────────────────────────────────────  │      │
│  │                                                                  │      │
│  │  Function 1: image-compositor                                   │      │
│  │  ├─ Runtime: Python 3.11 + Lambda Layer (Pillow, fonts)        │      │
│  │  ├─ Memory: 2048MB, Timeout: 30s                                │      │
│  │  ├─ Trigger: HTTP API (from n8n)                                │      │
│  │  ├─ Input: Slide data + generated image URL                     │      │
│  │  └─ Output: Composited slide uploaded to S3                     │      │
│  │                                                                  │      │
│  │  Function 2: video-renderer (Future)                            │      │
│  │  ├─ Runtime: Python 3.11 + FFmpeg layer                         │      │
│  │  ├─ Memory: 3008MB, Timeout: 120s                               │      │
│  │  ├─ Trigger: HTTP API (from n8n)                                │      │
│  │  └─ Output: MP4 video for YouTube Shorts                        │      │
│  │                                                                  │      │
│  │  Concurrency: 10 (can handle 10 carousels simultaneously)       │      │
│  │  Scaling: Auto-scale to 1000 concurrent (AWS limit)             │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ STORAGE: S3 (or Cloudflare R2)                                  │      │
│  │ ──────────────────────────────────────────────────────────────  │      │
│  │                                                                  │      │
│  │  Bucket 1: nexus-templates                                      │      │
│  │  ├─ Purpose: Carousel templates (PSD exports)                   │      │
│  │  ├─ Access: Public read, Lambda write                           │      │
│  │  ├─ Size: ~100MB (5 templates × 20MB each)                     │      │
│  │  └─ Lifecycle: Never expire                                     │      │
│  │                                                                  │      │
│  │  Bucket 2: nexus-generated-images                               │      │
│  │  ├─ Purpose: Raw images from Gemini API                         │      │
│  │  ├─ Access: Private (Lambda only)                               │      │
│  │  ├─ Size: ~20GB (10,000 images × 2MB)                          │      │
│  │  └─ Lifecycle: Delete after 90 days                             │      │
│  │                                                                  │      │
│  │  Bucket 3: nexus-final-carousels                                │      │
│  │  ├─ Purpose: Final composited carousels                         │      │
│  │  ├─ Access: Public read (CDN-backed)                            │      │
│  │  ├─ Size: ~50GB (10,000 carousels × 5MB)                       │      │
│  │  └─ Lifecycle: Keep indefinitely (archive to Glacier >1yr)     │      │
│  │                                                                  │      │
│  │  CDN: CloudFront (or R2 with Cloudflare CDN)                    │      │
│  │  ├─ Cache TTL: 7 days                                           │      │
│  │  ├─ Edge locations: Global (50+ POPs)                           │      │
│  │  └─ Custom domain: cdn.nexus.yourdomain.com                     │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ AI SERVICES (3rd Party APIs)                                    │      │
│  │ ──────────────────────────────────────────────────────────────  │      │
│  │  • Groq Cloud (Llama 3.1 70B) - Fact generation                │      │
│  │  • Google Gemini 1.5 Pro - Content expansion                    │      │
│  │  • Google Imagen 3 - Image generation                           │      │
│  │  • Instagram Graph API - Publishing                             │      │
│  │  Called from: n8n (Pi) via HTTP requests                        │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐      │
│  │ MONITORING & OBSERVABILITY                                      │      │
│  │ ──────────────────────────────────────────────────────────────  │      │
│  │  • BetterStack - Uptime monitoring (Pi + Lambda)                │      │
│  │  • CloudWatch - Lambda logs + metrics                           │      │
│  │  • Sentry (Future) - Error tracking                             │      │
│  │  • Grafana Cloud (Future) - Centralized dashboards              │      │
│  └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↕
┌─────────────────────────────────────────────────────────────────────────────┐
│ EXTERNAL PLATFORMS (Publishing Destinations)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Instagram]  [YouTube]  [TikTok]  [Twitter/X]  [LinkedIn]  [Blog]       │
│  • Carousels  • Shorts   • Videos  • Threads    • Posts     • Articles    │
│  • Graph API  • Data API • TikTok  • API v2     • API       • Webhook     │
│                         API                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.2 Component Breakdown

#### 3.2.1 Raspberry Pi (Orchestration Hub)

**Role:** Central control plane for workflow management, scheduling, and coordination.

**Components:**

**n8n Workflow Engine**
- **Purpose:** Visual workflow orchestration, replaces manual scripting
- **Version:** n8n 1.14.0 (self-hosted)
- **Configuration:**
  ```yaml
  # docker-compose.yml (n8n service)
  n8n:
    image: n8nio/n8n:1.14.0
    container_name: nexus-n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=nexus.home.local
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168  # Keep 7 days
      - WEBHOOK_URL=https://nexus.yourdomain.com
      - GENERIC_TIMEZONE=America/Los_Angeles
      - N8N_METRICS=true  # Prometheus metrics
    volumes:
      - /home/user/nexus/n8n-data:/home/node/.n8n
    networks:
      - nexus-network
    depends_on:
      - postgres
      - redis
  ```

**PostgreSQL Database**
- **Purpose:** Persistent storage for workflow state, carousel metadata, brand configs
- **Version:** PostgreSQL 15.3
- **Optimizations:**
  ```sql
  -- Performance tuning for Pi
  ALTER SYSTEM SET shared_buffers = '256MB';
  ALTER SYSTEM SET effective_cache_size = '1GB';
  ALTER SYSTEM SET maintenance_work_mem = '128MB';
  ALTER SYSTEM SET checkpoint_completion_target = 0.9;
  ALTER SYSTEM SET wal_buffers = '16MB';
  ALTER SYSTEM SET default_statistics_target = 100;
  ALTER SYSTEM SET random_page_cost = 1.1;
  ALTER SYSTEM SET effective_io_concurrency = 200;

  -- Indexes for n8n
  CREATE INDEX idx_execution_data_created ON public.execution_entity(created_at);
  CREATE INDEX idx_workflow_entity_active ON public.workflow_entity(active);

  -- Custom tables for Nexus
  CREATE TABLE nexus_carousels (
      id SERIAL PRIMARY KEY,
      brand VARCHAR(50) NOT NULL,
      workflow_id VARCHAR(100) NOT NULL,
      fact_text TEXT NOT NULL,
      slides JSONB NOT NULL,
      asset_urls TEXT[],
      status VARCHAR(20) NOT NULL,  -- generating, ready, approved, published, failed
      telegram_message_id INTEGER,
      instagram_post_id VARCHAR(100),
      created_at TIMESTAMP DEFAULT NOW(),
      published_at TIMESTAMP
  );

  CREATE INDEX idx_carousels_status ON nexus_carousels(status, created_at);
  CREATE INDEX idx_carousels_brand ON nexus_carousels(brand, created_at);
  ```

**Redis Cache**
- **Purpose:** Job queuing, API response caching, rate limiting
- **Version:** Redis 7.2
- **Configuration:**
  ```conf
  # redis.conf
  maxmemory 512mb
  maxmemory-policy allkeys-lru
  save 900 1
  save 300 10
  save 60 10000
  appendonly yes
  appendfsync everysec
  ```

**Nginx Reverse Proxy**
- **Purpose:** SSL termination, external access, future load balancing
- **Configuration:**
  ```nginx
  # /etc/nginx/sites-available/nexus
  server {
      listen 443 ssl http2;
      server_name nexus.yourdomain.com;

      ssl_certificate /etc/letsencrypt/live/nexus.yourdomain.com/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/nexus.yourdomain.com/privkey.pem;

      location / {
          proxy_pass http://localhost:5678;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          # WebSocket support for n8n live updates
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
      }

      # Health check endpoint
      location /healthz {
          access_log off;
          return 200 "OK\n";
          add_header Content-Type text/plain;
      }
  }
  ```

#### 3.2.2 AWS Lambda (Compute Layer)

**Role:** Serverless execution of compute-intensive tasks (image composition, video rendering).

**Function: image-compositor**

```python
# lambda_functions/image_compositor/handler.py
import json
import boto3
import requests
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
import os

s3_client = boto3.client('s3')

TEMPLATES_BUCKET = os.environ['TEMPLATES_BUCKET']
OUTPUT_BUCKET = os.environ['OUTPUT_BUCKET']
FONT_PATH = '/opt/fonts/Montserrat-Bold.ttf'  # Lambda layer

def lambda_handler(event, context):
    """
    Composite a carousel slide from template + generated image.

    Input event:
    {
        "carousel_id": "uuid",
        "slide_num": 1,
        "slide_type": "hook",
        "title": "Amazing Fact!",
        "subtitle": "You won't believe this",
        "image_url": "https://storage.googleapis.com/...",
        "brand": "FactsMind"
    }

    Output:
    {
        "statusCode": 200,
        "body": {
            "output_url": "https://cdn.nexus.com/carousels/{carousel_id}/slide_1.png",
            "processing_time_ms": 1234
        }
    }
    """

    import time
    start_time = time.time()

    try:
        # Parse input
        carousel_id = event['carousel_id']
        slide_num = event['slide_num']
        slide_type = event['slide_type']
        title = event['title']
        subtitle = event.get('subtitle', '')
        image_url = event.get('image_url')
        brand = event.get('brand', 'default')

        # Download template from S3
        template_key = f"{brand}/templates/template_{slide_type}.png"
        template_obj = s3_client.get_object(Bucket=TEMPLATES_BUCKET, Key=template_key)
        template_img = Image.open(BytesIO(template_obj['Body'].read()))

        # Download generated image (if applicable)
        if image_url and slide_num <= 4:  # First 4 slides have images
            response = requests.get(image_url, timeout=10)
            generated_img = Image.open(BytesIO(response.content))

            # Resize to fit template (1080×1350, image area is 1080×900)
            generated_img = generated_img.resize((1080, 900), Image.Resampling.LANCZOS)

            # Paste onto template (image area starts at y=0)
            template_img.paste(generated_img, (0, 0))

        # Add text overlay
        draw = ImageDraw.Draw(template_img)

        # Title text (large, bold)
        title_font = ImageFont.truetype(FONT_PATH, 72)
        title_bbox = draw.textbbox((0, 0), title, font=title_font)
        title_width = title_bbox[2] - title_bbox[0]
        title_x = (1080 - title_width) // 2
        title_y = 950 if image_url else 450

        # Text shadow for readability
        draw.text((title_x + 3, title_y + 3), title, fill='#000000', font=title_font)
        draw.text((title_x, title_y), title, fill='#FFFFFF', font=title_font)

        # Subtitle text (smaller)
        if subtitle:
            subtitle_font = ImageFont.truetype(FONT_PATH, 48)
            subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
            subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
            subtitle_x = (1080 - subtitle_width) // 2
            subtitle_y = title_y + 100

            draw.text((subtitle_x + 2, subtitle_y + 2), subtitle, fill='#000000', font=subtitle_font)
            draw.text((subtitle_x, subtitle_y), subtitle, fill='#CCCCCC', font=subtitle_font)

        # Save to buffer
        output_buffer = BytesIO()
        template_img.save(output_buffer, format='PNG', optimize=True)
        output_buffer.seek(0)

        # Upload to S3
        output_key = f"carousels/{carousel_id}/slide_{slide_num}.png"
        s3_client.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=output_key,
            Body=output_buffer,
            ContentType='image/png',
            CacheControl='public, max-age=604800'  # 7 days
        )

        # Generate CDN URL
        cdn_url = f"https://cdn.nexus.com/{output_key}"

        processing_time = int((time.time() - start_time) * 1000)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'output_url': cdn_url,
                'processing_time_ms': processing_time,
                'slide_num': slide_num
            })
        }

    except Exception as e:
        print(f"Error processing slide: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'carousel_id': carousel_id,
                'slide_num': slide_num
            })
        }
```

**Lambda Deployment Configuration:**

```yaml
# serverless.yml (using Serverless Framework)
service: nexus-lambda

provider:
  name: aws
  runtime: python3.11
  region: us-west-2
  memorySize: 2048
  timeout: 30
  environment:
    TEMPLATES_BUCKET: nexus-templates
    OUTPUT_BUCKET: nexus-final-carousels
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - s3:GetObject
            - s3:PutObject
          Resource:
            - arn:aws:s3:::nexus-templates/*
            - arn:aws:s3:::nexus-final-carousels/*

functions:
  image-compositor:
    handler: handler.lambda_handler
    layers:
      - arn:aws:lambda:us-west-2:123456789:layer:pillow-fonts:1
    events:
      - http:
          path: /composite
          method: post
          cors: true
    reservedConcurrency: 10  # Limit to 10 concurrent executions

layers:
  pillow-fonts:
    path: layers/pillow-fonts
    description: Pillow + custom fonts
    compatibleRuntimes:
      - python3.11

plugins:
  - serverless-python-requirements

custom:
  pythonRequirements:
    dockerizePip: true
    layer: true
```

**Lambda Layer Contents:**

```bash
# layers/pillow-fonts/
├── python/
│   └── lib/
│       └── python3.11/
│           └── site-packages/
│               └── PIL/  # Pillow library
└── fonts/
    ├── Montserrat-Bold.ttf
    ├── Montserrat-Regular.ttf
    └── Roboto-Bold.ttf

# Build layer
cd layers/pillow-fonts
pip install Pillow -t python/lib/python3.11/site-packages/
zip -r pillow-fonts.zip python/ fonts/
aws lambda publish-layer-version \
  --layer-name pillow-fonts \
  --zip-file fileb://pillow-fonts.zip \
  --compatible-runtimes python3.11
```

#### 3.2.3 S3 Storage (Asset Layer)

**Bucket Structure:**

```
nexus-templates/
├── FactsMind/
│   └── templates/
│       ├── template_hook.png       # Slide 1: Eye-catching hook
│       ├── template_problem.png    # Slide 2: Problem statement
│       ├── template_explanation.png # Slide 3: Core content
│       ├── template_example.png    # Slide 4: Example/visual
│       └── template_cta.png        # Slide 5: Call to action
└── TechDaily/  # Future brand
    └── templates/
        └── ...

nexus-generated-images/
├── 2025/
│   └── 11/
│       ├── 18/
│       │   ├── carousel-uuid-1-image-1.png
│       │   ├── carousel-uuid-1-image-2.png
│       │   └── ...
│       └── 19/
└── ...

nexus-final-carousels/
├── FactsMind/
│   ├── 2025/
│   │   └── 11/
│   │       ├── carousel-uuid-1/
│   │       │   ├── slide_1.png
│   │       │   ├── slide_2.png
│   │       │   ├── slide_3.png
│   │       │   ├── slide_4.png
│   │       │   └── slide_5.png
│   │       └── carousel-uuid-2/
│   │           └── ...
└── ...
```

**S3 Bucket Policies:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadFinalCarousels",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::nexus-final-carousels/*"
    },
    {
      "Sid": "LambdaWriteAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789:role/nexus-lambda-execution-role"
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::nexus-templates/*",
        "arn:aws:s3:::nexus-generated-images/*",
        "arn:aws:s3:::nexus-final-carousels/*"
      ]
    }
  ]
}
```

**CloudFront CDN Configuration:**

```json
{
  "OriginGroups": [],
  "Origins": [
    {
      "Id": "S3-nexus-final-carousels",
      "DomainName": "nexus-final-carousels.s3.us-west-2.amazonaws.com",
      "S3OriginConfig": {
        "OriginAccessIdentity": ""
      }
    }
  ],
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-nexus-final-carousels",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": ["GET", "HEAD", "OPTIONS"],
    "CachedMethods": ["GET", "HEAD"],
    "Compress": true,
    "DefaultTTL": 604800,
    "MaxTTL": 31536000,
    "MinTTL": 0
  },
  "PriceClass": "PriceClass_100",
  "ViewerCertificate": {
    "ACMCertificateArn": "arn:aws:acm:us-east-1:123456789:certificate/...",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "CustomDomain": "cdn.nexus.yourdomain.com"
}
```

---

### 3.3 Data Flow: Carousel Generation (Step-by-Step)

**End-to-End Flow: From Trigger to Published Post**

```
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: TRIGGER & INITIALIZATION (t=0s)                       │
└─────────────────────────────────────────────────────────────────┘

1. Cron trigger fires (e.g., 9:00 AM daily)
   ├─ n8n workflow: "Daily Carousel Generator" starts
   ├─ Read brand config from PostgreSQL:
   │  SELECT * FROM nexus_brands WHERE active=true AND name='FactsMind';
   ├─ Generate carousel_id: uuid.v4() → "a1b2c3d4-e5f6-..."
   └─ Log workflow start to database

2. Select topic for the day
   ├─ n8n Function node: selectTopic()
   ├─ Logic: Round-robin through topic list
   ├─ Topics: ["space", "history", "technology", "nature", "psychology"]
   └─ Output: topic="space"

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: CONTENT GENERATION (t=0s → t=15s)                     │
└─────────────────────────────────────────────────────────────────┘

3. Generate fact using Groq API (t=0s → t=3s)
   ├─ n8n HTTP Request node: POST to Groq Cloud
   ├─ Model: llama-3.1-70b-versatile
   ├─ Prompt: "Generate a fascinating fact about {topic} that would make a great Instagram carousel..."
   ├─ Response (3s): "The Great Red Spot on Jupiter has been raging for over 300 years..."
   └─ Cache in Redis: SET "fact:{hash}" "{fact}" EX 86400

4. Expand fact into 5-slide carousel (t=3s → t=10s)
   ├─ n8n HTTP Request node: POST to Gemini API
   ├─ Model: gemini-1.5-pro-latest
   ├─ Prompt: "Expand this fact into a 5-slide Instagram carousel structure..."
   ├─ Response (7s): JSON with 5 slides
   │  {
   │    "slides": [
   │      {"type": "hook", "title": "Jupiter's Eternal Storm", "subtitle": "300 Years and Counting", ...},
   │      {"type": "problem", "title": "How Is This Possible?", ...},
   │      {"type": "explanation", "title": "Jupiter's Atmosphere", ...},
   │      {"type": "example", "title": "Size Comparison", ...},
   │      {"type": "cta", "title": "Follow for More Space Facts", ...}
   │    ]
   │  }
   └─ Store in PostgreSQL: INSERT INTO nexus_carousels (...)

5. Generate images for slides 1-4 (t=10s → t=15s, parallel)
   ├─ n8n Loop over slides 1-4
   ├─ For each slide: HTTP Request to Gemini Imagen API (parallel)
   │  ├─ Prompt: slides[i].image_prompt
   │  ├─ Model: imagen-3.0-generate-001
   │  └─ Response: image_url (Google Cloud Storage URL)
   ├─ Parallelization: 4 requests execute simultaneously
   ├─ Processing time: 5s each, 5s total (not 20s sequential)
   └─ Output: [image_url_1, image_url_2, image_url_3, image_url_4]

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 3: IMAGE COMPOSITION (t=15s → t=20s)                     │
└─────────────────────────────────────────────────────────────────┘

6. Invoke Lambda functions for composition (parallel)
   ├─ n8n Loop over all 5 slides
   ├─ For each slide: HTTP Request to AWS Lambda
   │  POST https://your-lambda-url.amazonaws.com/composite
   │  {
   │    "carousel_id": "a1b2c3d4-e5f6-...",
   │    "slide_num": i,
   │    "slide_type": slides[i].type,
   │    "title": slides[i].title,
   │    "subtitle": slides[i].subtitle,
   │    "image_url": image_urls[i],  # or null for slide 5
   │    "brand": "FactsMind"
   │  }
   │
   │  Lambda executes (per slide):
   │  ├─ Download template from S3 (200ms)
   │  ├─ Download generated image (300ms)
   │  ├─ Composite with Pillow (500ms)
   │  ├─ Upload to S3 (200ms)
   │  └─ Return CDN URL (1.2s total per slide)
   │
   ├─ Parallelization: All 5 slides process simultaneously
   ├─ Processing time: 1.2s (not 6s sequential)
   └─ Output: [cdn_url_1, cdn_url_2, cdn_url_3, cdn_url_4, cdn_url_5]

7. Update database with final URLs
   ├─ PostgreSQL UPDATE:
   │  UPDATE nexus_carousels
   │  SET asset_urls = $1, status = 'ready'
   │  WHERE id = $2;
   └─ Commit transaction

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 4: HUMAN APPROVAL (t=20s → t=???)                        │
└─────────────────────────────────────────────────────────────────┘

8. Send preview to Telegram
   ├─ n8n Telegram node: sendMediaGroup
   ├─ Message: "New carousel ready for FactsMind! Review and approve:"
   ├─ Attachments: 5 images from CDN URLs
   ├─ Inline keyboard: [Approve] [Reject] [Edit]
   └─ Store telegram_message_id in database

9. Wait for approval (async workflow pause)
   ├─ n8n Webhook node: /approve/{carousel_id}
   ├─ Telegram bot callback handler
   └─ Workflow resumes when webhook receives POST

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 5: PUBLISHING (t=??? → t=???+5s)                          │
└─────────────────────────────────────────────────────────────────┘

10. Publish to Instagram
    ├─ n8n HTTP Request: POST to Instagram Graph API
    ├─ Endpoint: /me/media
    ├─ Parameters:
    │  {
    │    "image_url": cdn_url_1,  # First slide
    │    "caption": "{caption}\n\n{hashtags}",
    │    "children": [cdn_url_2, cdn_url_3, cdn_url_4, cdn_url_5],
    │    "media_type": "CAROUSEL"
    │  }
    ├─ Response: instagram_post_id
    └─ Update database:
       UPDATE nexus_carousels
       SET status='published', instagram_post_id=$1, published_at=NOW()
       WHERE id=$2;

11. Post-publish actions
    ├─ Send confirmation to Telegram: "Published! [View Post]"
    ├─ Update Redis stats: INCR "posts:published:2025-11-18"
    ├─ Trigger analytics workflow (optional)
    └─ Archive workflow execution logs

┌─────────────────────────────────────────────────────────────────┐
│ TOTAL TIME: ~20 seconds (automated) + human approval time      │
│ - Phase 1: 0s                                                   │
│ - Phase 2: 15s (AI generation)                                 │
│ - Phase 3: 5s (Lambda composition, parallel)                   │
│ - Phase 4: Variable (human in loop)                            │
│ - Phase 5: 5s (Instagram API)                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### 3.4 Technology Stack (Specific Versions & Justifications)

| Layer | Technology | Version | Justification |
|-------|------------|---------|---------------|
| **Orchestration** | n8n | 1.14.0 | • Self-hosted, no SaaS costs<br>• Visual workflows (easier to modify)<br>• 400+ integrations<br>• Active development<br>• Better than Zapier/Make for self-hosting |
| **Database** | PostgreSQL | 15.3 | • JSONB for flexible schema<br>• Row-level security (future multi-tenancy)<br>• Proven on Pi (current stack)<br>• Better than MySQL for JSON workloads |
| **Cache/Queue** | Redis | 7.2 | • In-memory speed (ms latency)<br>• Pub/sub for real-time updates<br>• Simple key-value for caching<br>• Lower overhead than RabbitMQ |
| **Reverse Proxy** | Nginx | 1.24 | • Industry standard<br>• Low memory footprint (~10MB)<br>• Better than Caddy for production |
| **Serverless Compute** | AWS Lambda | Python 3.11 | • Pay-per-use ($0.20/1M requests)<br>• Auto-scaling (0 → 1000 concurrent)<br>• Faster cold start than Python 3.9<br>• Better than Cloud Run (more mature) |
| **Object Storage** | AWS S3 | N/A | • 99.999999999% durability<br>• $0.023/GB/month<br>• CloudFront integration<br>• Alternative: Cloudflare R2 ($0.015/GB) |
| **CDN** | CloudFront | N/A | • 410+ edge locations<br>• $0.085/GB bandwidth<br>• Lowest latency globally<br>• Alternative: Cloudflare CDN (cheaper) |
| **AI - Facts** | Groq | Llama 3.1 70B | • Fastest inference (800 tokens/s)<br>• $0.59/1M tokens<br>• Better quality than GPT-3.5<br>• 10x cheaper than GPT-4 |
| **AI - Content** | Google Gemini | 1.5 Pro | • 2M token context window<br>• $3.50/1M tokens<br>• Better reasoning than Claude Sonnet<br>• Multimodal (future video) |
| **AI - Images** | Google Imagen | 3.0 | • Photorealistic quality<br>• $0.02/image<br>• Faster than DALL-E 3 (4s vs 10s)<br>• Better than Stable Diffusion XL |
| **Social API** | Instagram Graph API | v18.0 | • Official API (stable)<br>• Carousel support<br>• Scheduling (future)<br>• Better than scraping |
| **Monitoring** | BetterStack | N/A | • Uptime monitoring<br>• $10/month (5 monitors)<br>• SMS/Slack alerts<br>• Alternative: UptimeRobot (free) |
| **VPN** | Tailscale | Free | • Zero-config VPN<br>• WireGuard protocol<br>• Access Pi from anywhere<br>• Better than OpenVPN setup |
| **CI/CD (Future)** | GitHub Actions | N/A | • Free for public repos<br>• Docker build + push<br>• Auto-deploy to Pi<br>• Better than Jenkins (simpler) |

---

### 3.5 Implementation Plan (Phased Rollout)

#### Phase 1: Foundation Setup (Week 1)

**Goal:** Prepare infrastructure without disrupting production.

**Tasks:**
1. **AWS Account Setup**
   ```bash
   # Create AWS account
   # Enable billing alerts ($10/month threshold)
   # Create IAM user for Lambda deployment
   aws configure
   ```

2. **S3 Buckets Creation**
   ```bash
   # Create buckets
   aws s3 mb s3://nexus-templates --region us-west-2
   aws s3 mb s3://nexus-generated-images --region us-west-2
   aws s3 mb s3://nexus-final-carousels --region us-west-2

   # Enable versioning (safety)
   aws s3api put-bucket-versioning \
     --bucket nexus-final-carousels \
     --versioning-configuration Status=Enabled

   # Upload existing templates
   aws s3 sync /home/user/nexus/templates/ s3://nexus-templates/FactsMind/templates/
   ```

3. **Lambda Function Development**
   ```bash
   # Local development
   cd /home/user/nexus/lambda_functions/image_compositor
   python -m venv venv
   source venv/bin/activate
   pip install Pillow boto3 requests

   # Test locally
   python test_handler.py

   # Deploy with Serverless Framework
   npm install -g serverless
   serverless deploy --region us-west-2
   ```

4. **n8n Workflow Backup**
   ```bash
   # Backup current workflow before changes
   cp /home/user/nexus/n8n-data/workflows.json \
      /home/user/nexus/backups/workflows-backup-$(date +%Y%m%d).json
   ```

**Deliverables:**
- ✅ AWS infrastructure ready
- ✅ Lambda function deployed and tested
- ✅ S3 buckets configured
- ✅ Current workflow backed up

#### Phase 2: Hybrid Integration (Week 2)

**Goal:** Route image composition to Lambda while keeping everything else on Pi.

**Tasks:**
1. **Modify n8n Workflow**
   - Add HTTP Request nodes to call Lambda
   - Keep Groq/Gemini calls on Pi (no change)
   - Add error handling + fallback to Pi-based composition

   ```javascript
   // n8n HTTP Request node: Lambda Invocation
   {
     "method": "POST",
     "url": "{{ $env.LAMBDA_COMPOSITOR_URL }}",
     "body": {
       "carousel_id": "{{ $json.carousel_id }}",
       "slide_num": "{{ $json.slide_num }}",
       "slide_type": "{{ $json.slide_type }}",
       "title": "{{ $json.title }}",
       "subtitle": "{{ $json.subtitle }}",
       "image_url": "{{ $json.image_url }}",
       "brand": "FactsMind"
     },
     "options": {
       "timeout": 30000,  // 30s timeout
       "retry": {
         "maxTries": 3,
         "waitBetweenTries": 1000
       }
     }
   }

   // n8n IF node: Check Lambda response
   // If status != 200, fallback to local composition
   ```

2. **Parallel Execution Test**
   - Enable n8n's "Split In Batches" node
   - Set batch size = 5 (all slides)
   - Verify 5 Lambda invocations run simultaneously

3. **Database Schema Update**
   ```sql
   -- Add columns for cloud metadata
   ALTER TABLE nexus_carousels
   ADD COLUMN processing_method VARCHAR(20) DEFAULT 'local',  -- 'local' or 'lambda'
   ADD COLUMN processing_time_ms INTEGER,
   ADD COLUMN lambda_invocation_ids TEXT[];
   ```

**Testing:**
- Run 3 test carousels end-to-end
- Verify Lambda invocations in CloudWatch Logs
- Measure processing time improvement
- Check S3 uploads successful

**Deliverables:**
- ✅ Hybrid workflow operational
- ✅ Performance improvement validated (60s → 20s)
- ✅ Error handling tested
- ✅ Monitoring dashboards set up

#### Phase 3: Optimization & Cost Monitoring (Week 3)

**Goal:** Fine-tune for cost efficiency and reliability.

**Tasks:**
1. **Lambda Optimization**
   ```python
   # Add connection pooling for S3
   from botocore.config import Config

   config = Config(
       max_pool_connections=50,
       retries={'max_attempts': 3}
   )
   s3_client = boto3.client('s3', config=config)

   # Optimize image processing
   # - Reduce image quality for faster uploads
   # - Use WebP format (smaller file size)
   template_img.save(output_buffer, format='WEBP', quality=85)
   ```

2. **Cost Monitoring Setup**
   ```bash
   # Enable AWS Cost Explorer
   # Set budget alerts
   aws budgets create-budget \
     --account-id 123456789 \
     --budget file://budget.json

   # budget.json
   {
     "BudgetName": "Nexus Monthly Limit",
     "BudgetLimit": {
       "Amount": "100",
       "Unit": "USD"
     },
     "TimeUnit": "MONTHLY",
     "BudgetType": "COST"
   }
   ```

3. **CloudFront CDN Setup**
   ```bash
   # Create CloudFront distribution
   aws cloudfront create-distribution \
     --distribution-config file://cloudfront-config.json

   # Update n8n to use CDN URLs
   # Before: https://nexus-final-carousels.s3.us-west-2.amazonaws.com/...
   # After:  https://cdn.nexus.yourdomain.com/...
   ```

4. **Backup Strategy**
   ```bash
   # Automated S3 backups to Glacier (cheap long-term storage)
   aws s3api put-bucket-lifecycle-configuration \
     --bucket nexus-final-carousels \
     --lifecycle-configuration file://lifecycle.json

   # lifecycle.json: Transition to Glacier after 365 days
   {
     "Rules": [{
       "Id": "ArchiveOldCarousels",
       "Status": "Enabled",
       "Transitions": [{
         "Days": 365,
         "StorageClass": "GLACIER"
       }]
     }]
   }
   ```

**Deliverables:**
- ✅ Cost tracking dashboard
- ✅ Lambda optimized (50% faster)
- ✅ CDN operational (global <100ms latency)
- ✅ Automated backups configured

#### Phase 4: Production Cutover (Week 4)

**Goal:** Full production deployment with monitoring.

**Tasks:**
1. **Production Validation**
   - Run 10 carousels through hybrid system
   - Verify Instagram publishing works
   - Check Telegram notifications
   - Validate database consistency

2. **Monitoring Setup**
   ```yaml
   # docker-compose.yml: Add Prometheus + Grafana (optional)
   prometheus:
     image: prom/prometheus:latest
     volumes:
       - ./prometheus.yml:/etc/prometheus/prometheus.yml
     ports:
       - "9090:9090"

   grafana:
     image: grafana/grafana:latest
     ports:
       - "3000:3000"
     environment:
       - GF_SECURITY_ADMIN_PASSWORD=secure_password
   ```

3. **Documentation Update**
   ```bash
   # Update CLAUDE.md with new architecture
   # Document Lambda deployment process
   # Create runbook for troubleshooting
   ```

4. **Rollback Plan**
   ```bash
   # If issues arise, quick rollback:
   # 1. Restore n8n workflow from backup
   cp /home/user/nexus/backups/workflows-backup-20251118.json \
      /home/user/nexus/n8n-data/workflows.json
   docker restart nexus-n8n

   # 2. Disable Lambda invocations (n8n environment variable)
   echo "ENABLE_LAMBDA=false" >> /home/user/nexus/.env
   docker restart nexus-n8n
   ```

**Deliverables:**
- ✅ Production system stable for 7 days
- ✅ Documentation complete
- ✅ Team trained (if applicable)
- ✅ Rollback plan tested

---

### 3.6 Code Examples: Key Integration Points

#### Example 1: n8n to Lambda Integration (Complete Workflow)

```json
{
  "name": "Hybrid Carousel Generator",
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [{"field": "cronExpression", "expression": "0 9,15,21 * * *"}]
        }
      },
      "name": "Daily Trigger",
      "type": "n8n-nodes-base.cron",
      "position": [0, 0]
    },
    {
      "parameters": {
        "functionCode": "return [\n  { json: { topic: 'space', carousel_id: $node['Generate UUID'].json.uuid } }\n];"
      },
      "name": "Select Topic",
      "type": "n8n-nodes-base.function",
      "position": [200, 0]
    },
    {
      "parameters": {
        "url": "https://api.groq.com/openai/v1/chat/completions",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendBody": true,
        "bodyParameters": {
          "parameters": [
            {"name": "model", "value": "llama-3.1-70b-versatile"},
            {"name": "messages", "value": "[{\"role\": \"user\", \"content\": \"Generate fact about {{$json.topic}}\"}]"},
            {"name": "max_tokens", "value": "500"}
          ]
        }
      },
      "name": "Groq - Generate Fact",
      "type": "n8n-nodes-base.httpRequest",
      "position": [400, 0]
    },
    {
      "parameters": {
        "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent",
        "sendBody": true,
        "bodyParameters": {
          "parameters": [
            {"name": "contents", "value": "[{\"parts\": [{\"text\": \"Expand to carousel: {{$json.fact}}\"}]}]"}
          ]
        }
      },
      "name": "Gemini - Expand to Carousel",
      "type": "n8n-nodes-base.httpRequest",
      "position": [600, 0]
    },
    {
      "parameters": {
        "batchSize": 1,
        "options": {}
      },
      "name": "Loop Over Slides",
      "type": "n8n-nodes-base.splitInBatches",
      "position": [800, 0]
    },
    {
      "parameters": {
        "url": "https://your-lambda-url.amazonaws.com/composite",
        "method": "POST",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\n  \"carousel_id\": \"{{$json.carousel_id}}\",\n  \"slide_num\": {{$json.slide_num}},\n  \"slide_type\": \"{{$json.slide_type}}\",\n  \"title\": \"{{$json.title}}\",\n  \"subtitle\": \"{{$json.subtitle}}\",\n  \"image_url\": \"{{$json.image_url}}\",\n  \"brand\": \"FactsMind\"\n}",
        "options": {
          "timeout": 30000,
          "retry": {
            "maxTries": 3,
            "waitBetweenTries": 1000
          }
        }
      },
      "name": "Lambda - Composite Slide",
      "type": "n8n-nodes-base.httpRequest",
      "position": [1000, 0]
    },
    {
      "parameters": {
        "operation": "sendMediaGroup",
        "chatId": "{{$env.TELEGRAM_CHAT_ID}}",
        "media": "={{$json.cdn_urls.map(url => ({type: 'photo', media: url}))}}",
        "additionalFields": {
          "reply_markup": {
            "inline_keyboard": [[
              {"text": "✅ Approve", "callback_data": "approve_{{$json.carousel_id}}"},
              {"text": "❌ Reject", "callback_data": "reject_{{$json.carousel_id}}"}
            ]]
          }
        }
      },
      "name": "Telegram - Send Preview",
      "type": "n8n-nodes-base.telegram",
      "position": [1200, 0]
    }
  ],
  "connections": {
    "Daily Trigger": {"main": [[{"node": "Select Topic", "type": "main", "index": 0}]]},
    "Select Topic": {"main": [[{"node": "Groq - Generate Fact", "type": "main", "index": 0}]]},
    "Groq - Generate Fact": {"main": [[{"node": "Gemini - Expand to Carousel", "type": "main", "index": 0}]]},
    "Gemini - Expand to Carousel": {"main": [[{"node": "Loop Over Slides", "type": "main", "index": 0}]]},
    "Loop Over Slides": {"main": [[{"node": "Lambda - Composite Slide", "type": "main", "index": 0}]]},
    "Lambda - Composite Slide": {"main": [[{"node": "Telegram - Send Preview", "type": "main", "index": 0}]]}
  }
}
```

#### Example 2: Pi-Based Fallback (Error Handling)

```python
# scripts/local_compositor.py (fallback if Lambda fails)
# This script runs on Pi as backup

import sys
import json
from PIL import Image, ImageDraw, ImageFont
import requests
from pathlib import Path

def compose_slide_local(slide_data):
    """Fallback compositor that runs on Pi."""
    try:
        # Load template from local filesystem
        template_path = Path(f"/home/user/nexus/templates/template_{slide_data['slide_type']}.png")
        template = Image.open(template_path)

        # Download generated image if applicable
        if slide_data.get('image_url'):
            response = requests.get(slide_data['image_url'], timeout=10)
            gen_img = Image.open(BytesIO(response.content))
            gen_img = gen_img.resize((1080, 900), Image.Resampling.LANCZOS)
            template.paste(gen_img, (0, 0))

        # Add text overlay (same logic as Lambda)
        draw = ImageDraw.Draw(template)
        font = ImageFont.truetype('/home/user/nexus/fonts/Montserrat-Bold.ttf', 72)
        # ... (text rendering code)

        # Save locally
        output_path = Path(f"/home/user/nexus/output/slide_{slide_data['slide_num']}.png")
        template.save(output_path, format='PNG', optimize=True)

        return {
            'success': True,
            'output_path': str(output_path),
            'method': 'local'
        }

    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

if __name__ == '__main__':
    slide_data = json.loads(sys.argv[1])
    result = compose_slide_local(slide_data)
    print(json.dumps(result))
```

```javascript
// n8n Function node: Lambda with Fallback
const lambdaUrl = 'https://your-lambda-url.amazonaws.com/composite';
const slideData = {
  carousel_id: $json.carousel_id,
  slide_num: $json.slide_num,
  // ... other fields
};

try {
  // Try Lambda first
  const response = await $http.post(lambdaUrl, slideData, { timeout: 30000 });

  if (response.statusCode === 200) {
    return [{
      json: {
        output_url: response.body.output_url,
        processing_method: 'lambda',
        processing_time_ms: response.body.processing_time_ms
      }
    }];
  } else {
    throw new Error(`Lambda returned ${response.statusCode}`);
  }

} catch (error) {
  // Fallback to local Pi-based composition
  console.log('Lambda failed, falling back to local composition:', error.message);

  const { execSync } = require('child_process');
  const result = execSync(
    `python3 /home/user/nexus/scripts/local_compositor.py '${JSON.stringify(slideData)}'`
  ).toString();

  const localResult = JSON.parse(result);

  if (localResult.success) {
    return [{
      json: {
        output_path: localResult.output_path,
        processing_method: 'local',
        processing_time_ms: null
      }
    }];
  } else {
    throw new Error(`Both Lambda and local composition failed: ${localResult.error}`);
  }
}
```

#### Example 3: PostgreSQL Queries for Hybrid System

```sql
-- Query: Get carousel processing statistics
SELECT
  DATE(created_at) as date,
  processing_method,
  COUNT(*) as carousel_count,
  AVG(processing_time_ms) as avg_time_ms,
  MIN(processing_time_ms) as min_time_ms,
  MAX(processing_time_ms) as max_time_ms
FROM nexus_carousels
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at), processing_method
ORDER BY date DESC, processing_method;

-- Expected output:
--    date     | processing_method | carousel_count | avg_time_ms | min_time_ms | max_time_ms
-- -----------|-------------------|----------------|-------------|-------------|-------------
-- 2025-11-18 | lambda            |             12 |        5234 |        4102 |        6897
-- 2025-11-18 | local             |              1 |       58392 |       58392 |       58392
-- 2025-11-17 | lambda            |             15 |        5102 |        4523 |        6234

-- Query: Find carousels that failed Lambda and used fallback
SELECT
  id,
  carousel_id,
  processing_method,
  status,
  created_at
FROM nexus_carousels
WHERE processing_method = 'local'
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;

-- Trigger: Auto-update timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_carousel_modtime
  BEFORE UPDATE ON nexus_carousels
  FOR EACH ROW
  EXECUTE FUNCTION update_modified_column();
```

---

### 3.7 Expected Performance Improvements

| Metric | Nexus 1.0 (Pi-Only) | Nexus 2.0 (Hybrid) | Improvement |
|--------|---------------------|-------------------|-------------|
| **Carousel Generation Time** | 60 seconds | 20 seconds | 3x faster |
| **Image Composition** | 40s sequential | 5s parallel | 8x faster |
| **Throughput Capacity** | 3 posts/day | 100 posts/day | 33x more |
| **Pi CPU Usage** | 80% average | 25% average | 55% reduction |
| **Pi RAM Usage** | 3.2 GB / 4 GB | 1 GB / 4 GB | 69% reduction |
| **Cost per Carousel** | $0.50 | $0.45 | 10% cheaper |
| **Uptime (estimated)** | 95% | 99.5% | 4.5% improvement |
| **Global Latency** | N/A (local) | <100ms (CDN) | New capability |

**Break-Even Analysis:**
- Hybrid system costs +$45/month vs Pi-only
- But enables 33x more throughput
- If scaling to 10+ posts/day, cost per post drops 80%
- ROI: Positive if generating >15 posts/day

---

*Section 3 Complete. Next: Section 4 - Alternative Technology Stack Comparisons*
