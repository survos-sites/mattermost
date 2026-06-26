# museado-chat — self-hosted Mattermost + Agents plugin

Self-hosted Mattermost (Team Edition, free) for `chat.museado.org`. Hosts the
**Agents** plugin, which calls zm's OpenAI-compatible persona shim
(`POST /v1/chat/completions`) to answer `@Curator` / `@Scholar` / `@Librarian`
mentions with RAG over folio. See `survos-sites/scanseum#7`.

**Direction of data flow:** Mattermost *calls* zm. zm holds the Anthropic/OpenAI
key and the agents; Mattermost only needs the shim URL + a shared bearer token.

```
@Curator …  →  Mattermost Agents plugin  →  POST {zm}/v1/chat/completions  →  RAG + model  →  reply posted to thread
```

## Versions (pinned)

- **Server:** `mattermost/mattermost-team-edition:11.8.2` (in `Dockerfile`).
  The `FROM` tag is the version pin — bump it, commit, redeploy.
- **Agents plugin:** the one *bundled* with 11.8.2 (auto-installed via
  `MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS=true`). No manual download.
  - The standalone `mattermost-plugin-agents` v2.4.x requires server **11.9.0+**
    (only an RC today). To use it, bump the server to `11.9.0-rc2` *or* drop the
    plugin's `*-linux-amd64.tar.gz` into `plugins/` and uncomment the `COPY` in
    the Dockerfile. Stick with the bundled plugin until 11.9 goes stable.

## Local (docker-compose)

```bash
docker compose up -d --build
docker compose logs -f mattermost      # wait for "Server is listening on :8065"
open http://localhost:8065             # create the first admin account
```

Then in **System Console → Plugins → Agents**:
1. Enable the plugin.
2. Add an **OpenAI-Compatible** AI service:
   - URL: `http://host.docker.internal:8000/v1` (zm dev server on the host)
   - API key: the shared bearer token zm checks
   - Model: the persona id zm routes on (e.g. `curator`)
   - **Use Responses API: off** (we expose classic `/v1/chat/completions`)
3. Register the bot(s) and `@`-mention one in a channel.

`host.docker.internal` resolves on Linux because of the `extra_hosts:
host-gateway` line in the compose file.

Reset everything: `docker compose down -v` (drops the named volumes).

## Dokku (prod) — different wiring, same image

```bash
# one-time
dokku apps:create museado-chat
dokku postgres:create museado-chat
dokku postgres:link  museado-chat museado-chat          # sets DATABASE_URL
dokku config:set museado-chat \
  MM_SQLSETTINGS_DRIVERNAME=postgres \
  MM_SERVICESETTINGS_SITEURL=https://chat.museado.org \
  MM_PLUGINSETTINGS_ENABLE=true \
  MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS=true
# Mattermost wants MM_SQLSETTINGS_DATASOURCE, not DATABASE_URL — map it:
dokku config:set museado-chat MM_SQLSETTINGS_DATASOURCE="$(dokku config:get museado-chat DATABASE_URL)?sslmode=disable"
dokku ports:set museado-chat http:80:8065 https:443:8065

# PERSISTENCE — without these, redeploy wipes uploads/config/plugins:
for d in data config plugins client-plugins; do
  dokku storage:mount museado-chat "/var/lib/dokku/data/storage/museado-chat-$d:/mattermost/${d/client-/client/}"
done

git remote add dokku dokku@<host>:museado-chat
git push dokku main
dokku letsencrypt:enable museado-chat
```

> ⚠️ The plugin's AI-service config (endpoint URL, bearer, persona bots) is
> nested JSON not cleanly set via `MM_*` env vars — configure it once in the
> System Console UI. It persists in the mounted `/mattermost/config`. Treat that
> as state, or export `config.json` and bake a baseline into the image later.
