# SQL hosting options for Cove

Researched 22 September 2026. USD, before tax. Research only: no accounts or services provisioned by the agent, credentials moved, or mail uploaded. The user subsequently created PlanetScale `cove`; MCP read-only discovery confirms readiness. Prices are published allowances, not measured Cove capacity.

## Recommendation

The user prefers **PlanetScale Postgres + Cloud Run**. Use one PS-5 single-node branch for the personal pilot, with region/configuration price confirmed before deployment. Its reference compute is $5/month, 512 MiB RAM and 1/16 vCPU. Keep ordinary PostgreSQL migrations and an application API so switching providers remains practical. Supabase Free remains an option for integrated services, and Aiven Free/Developer for a free-to-low-cost database path. MCP inspection confirms the provisioned database is PS-5 ARM with zero replicas in AWS us-east-1, matching the reference compute configuration. Actual billing still includes any usage overages and taxes.

PlanetScale's documented network-attached allowance includes 10 GB disk, backup storage at twice configured disk, and 10 GB/month public egress for PS-5 non-HA. Use its included local PgBouncer rather than adding a dedicated pooler. Each additional branch is billed separately. The selected small single-node configuration has no HA; capacity must be measured. [Pricing details](https://planetscale.com/docs/postgres/pricing), [Connections](https://planetscale.com/docs/postgres/connecting)

The earlier $8–30/month personal estimate assumed **paid Neon**, not a minimum cost to operate Cove. A free database can serve a running app for $0 while it stays within its allowances. Going live or receiving revenue does not itself select a paid plan. Free capacity is finite; restrictions and reliability requirements can force an upgrade before there are many users.

## PostgreSQL comparison

| Provider | Starting allowance or price | Main constraint for Cove | Paid path |
| --- | --- | --- | --- |
| **Supabase Free** | $0; 500 MB database, 1 GB file storage, 5 GB uncached egress, 50,000 monthly active auth users; two active free projects | No included automatic backups; inactivity pause after one week; small shared compute. API request count is unlimited, but capacity and transfer are not. | Pro starts at $25/month including one Micro project; additional projects, larger compute and overages can add cost. [Pricing](https://supabase.com/pricing) |
| **Aiven Free** | $0; 1 GB database disk, 1 GB RAM, one CPU, single node; backups included | 20 connections, no managed connection pool, no VPC, no SLA; idle services can power off. Provider may change free service placement. | Developer starts at $5/month with 8 GB disk, 1 GB RAM, always-on service and basic backups; still single node, not HA. [Free limits](https://aiven.io/docs/products/postgresql/concepts/pg-free-tier), [Developer](https://aiven.io/developer-tier-pg-mysql) |
| **Neon Free** | $0; 0.5 GB DB, 100 CU-hours/project/month, 5 GB public egress/project | At 0.25 CU, allowance equals 400 awake hours, approximately 13.3 hours/day in a 30-day month. Frequent queries keep compute awake. | Launch meters compute at $0.106/CU-hour plus storage; no monthly minimum. [Pricing](https://neon.com/pricing) |
| **PlanetScale Postgres** | Single-node PS-5 compute starts at $5/month in the reference AWS us-east-1 catalog: 512 MiB RAM, 1/16 vCPU | No ongoing free plan identified; very small compute; quote storage, backup and egress allowances separately. | Larger single-node or HA configurations. The $5 compute SKU is not a universal all-inclusive bill. [Pricing catalog](https://planetscale.com/pricing.md) |
| **Railway Postgres** | $5 trial credit for 30 days, then Free includes $1/month of resource credit; Hobby $5 minimum monthly usage | Resource metering can exhaust the small free credit. Not a guaranteed free always-on DB. | Hobby includes $5 usage, then charges excess resources. [Pricing](https://railway.com/pricing) |
| **Google Cloud SQL** | PostgreSQL trial instance for up to 30 days, not an ongoing free database tier | Trial stops serving after expiry without upgrade. Normal instances add persistent compute, disk and backup charges. | Paid Cloud SQL; strongest fit when single-cloud operations outweigh initial cost. [Trial terms](https://docs.cloud.google.com/sql/docs/postgres/free-trial-instance), [Pricing](https://cloud.google.com/sql/pricing) |

Neon suspends compute when the free CU-hour allowance is exhausted until the next billing period or an upgrade. Its free storage cap also limits writes. [Neon free-plan limits](https://github.com/neondatabase/website/blob/main/content/faqs/free-plan-limits-and-quotas.md)

Aiven's Developer page contains a headline availability claim, but its detailed FAQ says the tier is a single node without HA and directs mission-critical workloads to higher plans. Do not interpret the headline as an HA guarantee. Its backups are basic disaster recovery, not a substitute for user-controlled point-in-time recovery. Specific cloud/region selection is limited. [Developer FAQ](https://aiven.io/developer-tier-pg-mysql)

## Other SQL engines

| Provider | Free allowance | Fit for Cove |
| --- | --- | --- |
| **Turso** | 5 GB storage, 500 million rows read/month, 10 million rows written/month, 100 databases; one-day point-in-time restore | Attractive if we choose its SQLite-compatible SQL stack. It is not interchangeable with PostgreSQL: adapt drivers, migrations, concurrency and tenant isolation. Large free storage is its main advantage here. [Pricing](https://turso.tech/pricing), [Documentation](https://docs.turso.tech/introduction) |
| **Cloudflare D1** | 5 million rows read/day, 100,000 written/day, 5 GB total account storage, but **500 MB per free database** | SQLite-based, naturally paired with Workers. Cloud Run can use an HTTP integration, but this changes the proposed PostgreSQL architecture. Scanned rows, including index maintenance, count toward usage. [Pricing](https://developers.cloudflare.com/d1/platform/pricing/), [Limits](https://developers.cloudflare.com/d1/platform/limits/), [Overview](https://developers.cloudflare.com/d1/) |

D1 rejects queries when daily free read/write limits are exhausted, until reset or upgrade; storage exhaustion prevents growth. Neither its 5 GB account allowance nor Turso's SQL support implies a drop-in Postgres replacement. Self-hosted PostgreSQL is another option, but leaves patching, recovery and availability with us; that works against the request for easy, secure hosting.

## What Supabase Free means in practice

There is no automatic transition to paid pricing because Cove starts operating. Keep the organization on Free and stay under its quotas. Exceeding them produces notices and eventually restrictions, potentially paused projects, read-only databases or API failures; it does not buy more capacity automatically. [Billing FAQ](https://supabase.com/docs/guides/platform/billing-faq)

Use one shared project with explicit account ownership and isolation. Supabase's 50,000 auth-user allowance is not evidence that 500 MB or shared compute can support that many mailboxes. Do not multiply free projects to evade plan limits. Storage, indexes, traffic, query latency, backup needs and acceptable downtime determine when to upgrade.

Connection plan for Cloud Run: use Supabase's shared transaction pooler, verified TLS and small application pools. The shared pooler supports IPv4, so a paid dedicated IPv4 endpoint is not inherently needed. Use the supported direct/session connection for migrations and exports, verify network reachability, and keep transaction-pool limitations out of those jobs. [Connection guide](https://supabase.com/docs/guides/database/connecting-to-postgres)

Keep email tables in a private schema behind Cloud Run, with a restricted runtime database role and owner-scoped RLS. If any tables are exposed through the Supabase Data API, add explicit grants and RLS policies. Never ship database passwords or the service-role key to Mac/mobile. Keep credentials in Secret Manager and preserve the backend plan's encrypted email fields and explicit cloud opt-in. Built-in Supabase Auth does not replace Google's Gmail permission grant, and Realtime does not implement offline conflict handling or Gmail history synchronization for us. [API security](https://supabase.com/docs/guides/api/securing-your-api)

Supabase Free has no included automatic backups. Before persisting real Cove-only data, schedule encrypted exports and test restoring contacts, preferences, drafts and decisions. Gmail can reconstruct mail, but cannot reconstruct those records. Back up object bodies separately if needed; SQL dumps alone do not contain them.

## Capacity and cost assumptions for the pilot

At 100 new emails/day for 30 days, one user contributes 3,000 messages. If metadata, decisions, relationships and indexes average **4–10 KB per message**, that is **12–30 MB per user per month**, excluding project baseline, auth, jobs, drafts, contact notes and bloat. This is an illustrative assumption to measure on the final schema, not a benchmark. Keep full bodies and attachments out of PostgreSQL.

At the existing 50 KB/body assumption, a 30-day body cache is **150 MB per user**. Ten users would consume roughly **1.5 GB**, already exceeding Supabase's 1 GB free object-storage allowance, even if SQL still fits. Attachments can dominate both size and download traffic; fetch them on demand. Use the planned encrypted Cloud Storage cache or a bounded private Supabase Storage cache, and account for the chosen service separately.

Start with one account and a bounded recent-mail import. Measure actual SQL bytes, object bytes, request latency, connection peaks and egress. Review capacity at roughly 70% of any storage/traffic quota, before mail processing becomes read-only or blocked. Configure real backups; do not synthesize activity just to evade provider inactivity rules.

| Component | One-user pilot cost basis |
| --- | --- |
| Supabase database on Free | **$0 while within allowances** |
| Cloud Run request-based API/worker | Potentially $0 within monthly free allowances with minimum instances zero; billing and network charges still apply independently. [Cloud Run pricing](https://cloud.google.com/run/pricing) |
| Jev | About **$0.66/month** for 3,000 messages × 5,000 total input tokens × 1.05 retries × $0.042/million; not a measured token distribution. Output is free. [TypeSafe pricing](https://docs.typesafe.ai/models) |
| Other Google services and backups | Separate usage charges/allowances for KMS, Storage, secrets, queues, logs, builds and network. Retain the backend plan's accounting; a free database does not make these free. |

For a free-tier alternative, the estimate is **$0 database + estimated Jev + measured Google/backup usage**, rather than a mandatory $8–30/month. For the preferred PlanetScale pilot, use **$5 database + approximately $0.66 Jev + Google services/any overages**, subject to the selected region's SKU price. Cloud Run's free allowance is shared across the billing account. No fixed total bill, hard spending cap or user-capacity claim is implied.
