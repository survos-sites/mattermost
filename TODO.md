# AI channel integration

- [ ] Build a shared Symfony channel gateway using standard Mattermost bot APIs.
  Route mentions to app-specific agents (AskRappNews, Bills, Curator) and keep
  channel/thread history isolated. Support background processing, duplicate
  delivery protection, authentication, source links and error reporting.
  This is independent of the Agents plugin's service/agent/channel licensing.
- [ ] Connect AskRappNews to the AI Lab / Ask Rapp News channel through that gateway.
  Current Agents 2.9.0 Team Edition demo uses direct messages only.
- [ ] Add Bills and restore Curator when its backend is available.
- [ ] Consider a broader AskRapp agent with separate news, gravestone, NARA-photo
  and other public-data tools; keep source provenance explicit.
- [ ] Assess PostgreSQL 18/19 in a restored test database before migrating the
  dedicated Mattermost PostgreSQL 16 service. Verify published Timescale images
  separately if that distribution is chosen.
