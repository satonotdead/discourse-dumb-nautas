# Power Tools Nautas

The Discourse plugin behind [Criptonautas](https://criptonautas.co): moderator tools, privacy features and a lightweight phone client, in one install. Every feature has its own switch, so you only run what you need.

## What's inside

**For moderators**

- **[Moderator tools](docs/features/moderator-tools.md).** Private replies to chosen people inside a topic, private team notes, alerts when another moderator acts, checklists before posting, and topic tools such as footer messages and reply approval.
- **[Mini-mod](docs/features/mini-mod.md).** Extra rights for people who moderate a single category: managing it, moving topics, tags. Never past what they can see.
- **[Dislike](docs/features/dislike.md).** In the categories you choose, likes stop counting: no notifications, no history, no totals.

**For members**

- **[Dumbcourse](docs/features/dumbcourse.md).** The forum at `/dumb`, light enough for basic phones and old browsers, with an optional leaderboard. On forums that sign in through an SSO, it uses the forum's own sign-in.
- **[Smart search](docs/features/smart-search.md).** When a search finds too little, it tries again with synonyms, in the searcher's language (English or Spanish).
- **[Desktop pop-ups](docs/features/popups.md).** A small card in the corner when a notification arrives.
- **[REQ-PM](docs/features/reqpm.md).** Members ask each other for contact details and choose exactly what to share. Off by default.

**Behind the scenes**

- **[Disteleplus](docs/features/disteleplus.md).** A team chat room mirrored both ways with a Telegram group, with the review queue in Telegram too.
- **[Another SMTP](docs/features/another-smtp.md).** Send forum email through a different mail server.
- **[Translator tweaks](docs/features/translator-tweaks.md).** A proxy for the Translator plugin's Google requests.

It also works alongside [discourse-category-lockdown-nautas](https://github.com/somos-criptonautas/discourse-category-lockdown-nautas): private replies stay visible to their audience inside lockdown topics.

The interface is available in English and Spanish.

## Installing

Add the plugin to your `app.yml` and rebuild:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/somos-criptonautas/discourse-power-tools-nautas.git
```

```bash
cd /var/discourse
./launcher rebuild app
```

Keep the folder name lowercase: Discourse builds the plugin's stylesheet address from it.

## Turning things on

Everything is under **Admin → Plugins → Power Tools Nautas**, one tab per feature. `jtech_enabled` is the master switch: off stops everything at once, including permission changes and background jobs. Switching private replies off never makes an existing one public.

## Working on it

Read the [repository rules](AGENTS.md), [CONTRIBUTING.md](CONTRIBUTING.md) and [EDITION.md](EDITION.md), which explains how this repo syncs with the code it builds on. Developer docs are in [docs/](docs/README.md). Security problems: see [SECURITY.md](SECURITY.md).

## License

[GPL-3.0](LICENSE). Original authors: TripleU, Shalom Karr and Ars18.
