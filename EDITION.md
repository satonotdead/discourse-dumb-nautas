# Dumb Nautas edition

Criptonautas' edition of [JtechTools](https://github.com/JTech-Forums/JtechTools).
It tracks upstream `main` and adds a thin layer of changes on top, kept small so
upstream merges stay easy.

## What this edition changes

- **Name.** Shows as "Dumb Nautas" in the admin (plugin list, settings
  categories). The internal plugin id stays `jtech-tools`, so admin URLs are
  `/admin/plugins/jtech-tools/…`.
- **Spanish.** `config/locales/*.es.yml` in the community voice: historia,
  respuesta, respuesta privada, team, reto; impersonal, voseo only in direct
  notices.
- **Smart search in Spanish.** Spanish searchers get Spanish synonyms from the
  [Open Multilingual Wordnet](https://github.com/omwn) (MCR 3.0, CC BY 3.0),
  in `config/dictionaries/smart_search_synonyms_es.txt`; everyone else gets
  WordNet. Spanish stop words are never expanded.
- **category-lockdown.** Mod whispers stay visible to their audience inside
  lockdown topics (`sub_plugins/nautas.rb`).
- **Dumbcourse.**
  - Optional discourse-gamification leaderboard (`dumbcourse_leaderboard_id`).
  - On forums that sign in elsewhere (DiscourseConnect, or no local logins,
    e.g. an OIDC SSO), `/dumb` sends sign-in to the full site and comes back
    to `/dumb` afterwards.
- **REQ-PM** is off by default and assumes no country code.
- **Migrations.** Disteleplus listen rows cascade with their message
  (`db/post_migrate`), and the Aug 30 migration only resets the module's
  master toggle.

## Install

```yaml
- git clone https://github.com/somos-criptonautas/discourse-dumb-nautas.git
```

## Sync with upstream

```bash
git remote add upstream https://github.com/JTech-Forums/JtechTools  # once
git fetch upstream
git merge upstream/main
```

After a merge:

- Add Spanish for any new English strings (both `.es.yml` files must have the
  same keys as their `.en.yml`).
- Rebuild Dumbcourse if `dumbcourse/` changed:
  ```bash
  pnpm dumbcourse:build
  ```
