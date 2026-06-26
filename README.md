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

- **Server:** `mattermost/mattermost-team-edition:11.8.2` (`Dockerfile`). The `FROM`
  tag is the version pin — bump it, commit, redeploy.
- **Agents plugin:** the one bundled with 11.8.2 (`mattermost-ai` v2.0.5, auto-installed
  via `MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS=true`). The standalone
  `mattermost-plugin-agents` v2.4.x needs server 11.9.0+ (RC only) — stay on the
  bundled plugin until 11.9 is stable.

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

### Not yet done

- **Persistence:** no `dokku storage:mount` yet — uploads/config/plugins are ephemeral
  and reset on redeploy. Add mounts for `/mattermost/{data,config,plugins,client/plugins}`
  (mind the uid-2000 ownership) before relying on it.
- First admin account + the Agents AI-service config (point it at the `ai-chat-bundle`
  shim) are done in the System Console after the edge is reachable.
