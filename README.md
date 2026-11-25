# mattermost — self-hosted Mattermost + Agents plugin

Self-hosted Mattermost (Team Edition, free) hosting the **Agents** plugin, which
calls a `survos/ai-chat-bundle` OpenAI-compatible persona shim to answer
`@Curator` / `@Scholar` / `@Librarian` mentions with RAG. See `survos-sites/scanseum#7`.

**Live:** https://chat.survos.com (Dokku). *(Not under `*.museado.org` — zm owns that
Dokku wildcard for tenants like `nara.museado.org`; chat lives on survos.com.)*

**Data flow:** Mattermost *calls* the app. The app holds the model key + agents;
Mattermost only needs the shim URL + a shared bearer token.

```
@Curator …  →  Agents plugin  →  POST {app}/v1/chat/completions  →  RAG + model  →  reply
```

## Versions (pinned)

- **Server:** `mattermost/mattermost-team-edition:12.1.0` (`Dockerfile`). The `FROM`
  tag is the version pin — bump it, commit, redeploy.
- **Agents plugin:** bundled with the server, auto-installed via
  `MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS=true`. Check the running version
  with `mmctl --local plugin list` after deployment.

## Local (docker-compose)

```bash
docker compose up -d --build
open http://localhost:8065        # create the first admin account
```
Note: the Symfony Mattermost notifier is https-only, so local plain-http can't be
driven by `ai-chat-bundle`'s `mm:post` — use the live https deploy below for that.

## Dokku deploy (how chat.survos.com was set up)

```bash
H=dokku@ssh.survos.com
ssh $H apps:create mattermost
ssh $H postgres:create mattermost-db
ssh $H postgres:link mattermost-db mattermost          # sets DATABASE_URL
# Mattermost wants MM_SQLSETTINGS_DATASOURCE, not DATABASE_URL — map it:
ssh $H "config:set --no-restart mattermost \
  MM_SQLSETTINGS_DRIVERNAME=postgres \
  'MM_SQLSETTINGS_DATASOURCE=<DATABASE_URL>?sslmode=disable&connect_timeout=10' \
  MM_SERVICESETTINGS_SITEURL=https://chat.survos.com \
  MM_PLUGINSETTINGS_ENABLE=true \
  MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS=true"
ssh $H domains:set mattermost chat.survos.com
ssh $H ports:add  mattermost http:80:8065

git remote add dokku dokku@ssh.survos.com:mattermost
git push dokku main                                    # builds the Dockerfile, deploys

ssh $H letsencrypt:set    mattermost email tac@museado.org
ssh $H letsencrypt:enable mattermost                   # http-01, valid cert on origin
```

### Cloudflare edge

`*.survos.com` is Cloudflare-proxied with **Flexible** SSL, which loops against Dokku's
forced https. Fix: add a **DNS-only (grey-cloud) A record** `chat → 5.161.107.103` in
Cloudflare. A specific record disables the wildcard for `chat` (drops the proxied
IPv6 too), so it resolves straight to the origin with the Let's Encrypt cert.

### Persistence and upgrades

Production uses PostgreSQL in the dedicated Dokku service `mattermost-db`.
The database was observed running `postgres:16.0` on 2026-11-25; changing the
compose image does not upgrade this production service.

Dokku mounts `/platform/mattermost/{data,config,plugins,client-plugins,logs}`
at the corresponding container directories (`client-plugins` maps to
`/mattermost/client/plugins`). Configuration and plugin mounts were preserved
from the previous container before upgrading to 12.1.0.

Before an upgrade, back up PostgreSQL with `pg_dump -Fc` and archive the mounted
data/config/plugins. The 12.1 upgrade backup is under
`/var/backups/mattermost/before-12.1-*` on fsn1 (root access only).
Database schema migrations can make an image-only rollback insufficient; keep
the matching database and file backup together.

After deployment, check `/api/v4/system/ping`, the server version, and
`mmctl --local plugin list`. Existing bots and AI services must also be checked.
