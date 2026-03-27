# Production: ALB + Nginx (headers, sessions)

Use this as the long-term reference for **`dev.kutoot.com` / production** traffic: **browser → ALB → Nginx → PHP-FPM → Laravel**.

## Nginx: large cookies / headers

Laravel session, Filament, and encrypted cookies can exceed **default Nginx buffer sizes**, which surfaces as:

`400 Bad Request — Request Header Or Cookie Too Large`

**Implemented in repo (all new instances):**

1. **`/etc/nginx/conf.d/99-kutoot-large-headers.conf`** — `http {}` context defaults for **every** vhost:
   - `client_header_buffer_size 32k;`
   - `large_client_header_buffers 8 64k;`

2. **`/etc/nginx/sites-available/kutoot-backend`** — same directives in the `server` block (explicit + matches `user-data`).

**Apply:** `terraform apply` in `terraform/02-asg` + **instance refresh** so new EC2 instances get user-data. For **existing** instances, copy the `conf.d` file from user-data or run the same snippet, then `nginx -t && systemctl reload nginx`.

## ALB: sticky sessions (sessions on multiple app instances)

**Problem:** With `SESSION_DRIVER=file` and **more than one** Laravel instance, each request may land on a **different** server without a shared session store — **login / admin** can behave erratically.

**Implemented in repo:** `terraform/01-alb` target group **stickiness** enabled:

- `type = lb_cookie`
- `cookie_duration = 86400` (1 day)

The ALB sets a cookie so the **same client** tends to use the **same target** until the cookie expires.

**Better long-term:** use **`SESSION_DRIVER=database`** or **`redis`** (shared across all instances) so sticky sessions are optional; **still keep** large Nginx buffers.

**Apply:** from `terraform/01-alb`:

```powershell
cd terraform/01-alb
terraform plan
terraform apply
```

Review the plan: target group changes may **replace** the TG in some cases; schedule a short maintenance window if needed.

## ALB: idle timeout

`idle_timeout = 120` seconds on the load balancer (helps large uploads / slow clients). Adjust in `terraform/01-alb/main.tf` if required.

## AWS header size limit (rare)

For **HTTP/1.1**, AWS documents a **request header** size limit (order of **16 KB** per request). If you ever exceed that **before** Nginx, the error may come from the ALB, not Nginx. Mitigations:

- Keep session payload small; avoid storing large blobs in session.
- Prefer **Redis/database** sessions with a **small** session cookie.
- Monitor cookie size in browser DevTools → **Application → Cookies**.

## Quick verification

```bash
# On an app instance
curl -sI http://127.0.0.1/ | head -5
sudo nginx -t
grep -E 'client_header|large_client' /etc/nginx/conf.d/99-kutoot-large-headers.conf
```
