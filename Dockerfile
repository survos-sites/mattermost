# Museado chat server — thin pin/extend over the official Mattermost image.
# The FROM tag IS our version pin (in git). Bump it, commit, redeploy.
#
# Mattermost ships the "Agents" plugin (formerly mattermost-plugin-ai)
# prepackaged, so we don't download/version-match it by hand — we just enable
# it (MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS=true) and point it at the
# zm OpenAI-compatible shim from the System Console. 11.9.0 (latest stable
# feature release, 2026-07-16) bundles Agents plugin v2.4.2 — up from 2.0.5
# on the old 11.8.2 pin.
#
# If we ever need a NEWER Agents plugin than the bundled one, drop its
# linux-amd64 tarball into /mattermost/prepackaged_plugins here (see README).
FROM mattermost/mattermost-team-edition:11.9.0

# Place to bake plugins / a baseline config.json later:
# COPY plugins/mattermost-plugin-agents-*-linux-amd64.tar.gz /mattermost/prepackaged_plugins/

# Outbound email (password resets, invites, verification) via Brevo's SMTP
# relay. Same account/settings in both local and prod (same image, per the
# docker-compose.yml comment) so they're baked in here -- only the actual
# secret (SMTPPASSWORD) is a runtime env var (compose .env locally, `dokku
# config:set` in prod).
ENV MM_EMAILSETTINGS_SENDEMAILNOTIFICATIONS=true \
    MM_EMAILSETTINGS_REQUIREEMAILVERIFICATION=false \
    MM_EMAILSETTINGS_FEEDBACKNAME="Museado Chat" \
    MM_EMAILSETTINGS_FEEDBACKEMAIL=tacman@gmail.com \
    MM_EMAILSETTINGS_REPLYTOADDRESS=tacman@gmail.com \
    MM_EMAILSETTINGS_SMTPSERVER=smtp-relay.brevo.com \
    MM_EMAILSETTINGS_SMTPPORT=465 \
    MM_EMAILSETTINGS_SMTPUSERNAME=tacman@gmail.com \
    MM_EMAILSETTINGS_CONNECTIONSECURITY=TLS \
    # Distinct from Username/Password being set -- Mattermost's persisted
    # config.json defaults this to false from before SMTP was configured at
    # all, and env-var overlay won't touch it unless set explicitly here.
    # Without it, Mattermost silently skips AUTH and MAIL FROM gets
    # rejected by Brevo with "502 5.7.0 Please authenticate first".
    MM_EMAILSETTINGS_ENABLESMTPAUTH=true

# Mattermost listens here; Dokku maps 80->8065 (see app.json).
EXPOSE 8065
