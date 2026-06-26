# Museado chat server — thin pin/extend over the official Mattermost image.
# The FROM tag IS our version pin (in git). Bump it, commit, redeploy.
#
# Mattermost 11.8.2 ships the "Agents" plugin (formerly mattermost-plugin-ai)
# prepackaged, so we don't download/version-match it by hand — we just enable
# it (MM_PLUGINSETTINGS_AUTOMATICPREPACKAGEDPLUGINS=true) and point it at the
# zm OpenAI-compatible shim from the System Console.
#
# If we ever need a NEWER Agents plugin than the bundled one, drop its
# linux-amd64 tarball into /mattermost/prepackaged_plugins here (see README).
FROM mattermost/mattermost-team-edition:11.8.2

# Place to bake plugins / a baseline config.json later:
# COPY plugins/mattermost-plugin-agents-*-linux-amd64.tar.gz /mattermost/prepackaged_plugins/

# Mattermost listens here; Dokku maps 80->8065 (see app.json).
EXPOSE 8065
