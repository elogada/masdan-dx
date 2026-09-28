# MASDAN-DX

> **There's an Intel Pack for that.**

MASDAN-DX turns Gemini-powered intelligence into something you do not have to
remember to ask for. Import an **Intel Pack**, set it in motion, and let the
insight come to you—in your inbox, on your phone, and at the moment it matters.

**Why write a prompt when you can just import an Intel Pack?**

## Intelligence that moves first

Most AI products wait. They wait for someone to open a tab, describe a problem,
refine a prompt, and ask again tomorrow. MASDAN-DX reverses that relationship.
It watches the web, uses Gemini to turn changing information into useful
intelligence, and delivers the result by email with user consent.

The result is an always-on intelligence layer built for people who have better
things to do than repeatedly prompt a chatbot:

- **Import, don't engineer.** Intel Packs package a repeatable intelligence
  mission into a portable JSON file.
- **Run on your terms.** Launch Intel Pack Jobs from the focused MASDAN-DX Intel
  Dashboard.
- **Let intelligence find you.** Receive useful, readable briefings where you
  already pay attention: your phone and inbox.
- **Powered by Gemini.** Gemini is the reasoning engine at the center of the
  workflow, transforming live web context into timely, actionable reports.

## Intel Packs in development

### Competitive Intelligence

Built for enterprise teams that cannot afford to discover a market shift too
late. Monitor competitors, products, positioning, and noteworthy moves, then
turn a sea of updates into a decision-ready intelligence report.

### Traffic Intelligence

Built for everyday movement. Turn changing road and travel conditions into a
concise update that arrives before the commute—not after you are already stuck
in it.

This is only the beginning. Weather, pricing, policy, security, research,
reputation—if it can be observed and distilled, **there's an Intel Pack for
that.**

## How it works

1. **Choose an Intel Pack.** Start with a portable intelligence workflow.
2. **Import it.** Add the JSON file from the MASDAN-DX Intel Dashboard at
   `/dashboard/`.
3. **Put Gemini to work.** The Intel Pack gathers web context and turns it into
   a focused briefing.
4. **Get the signal.** MASDAN-DX sends the intelligence to your inbox so it is
   ready on your phone.

## Run MASDAN-DX locally

### Prerequisites

- Docker
- A Gemini API key
- SMTP credentials for email delivery

Clone the repository and enter the project:

```bash
git clone https://github.com/elogada/masdan-dx
cd masdan-dx
```

Create your environment file:

```bash
cp .env.sample .env
```

Update `.env` with your Gemini API key, administrator credentials, and SMTP
credentials, then build and run:

```bash
docker build -t masdan-dx .
docker run --rm -p 8080:8080 --env-file .env masdan-dx
```

Open `http://localhost:8080/dashboard/` to launch the **MASDAN-DX Intel
Dashboard**. The full Open WebUI frontend remains available at
`http://localhost:8080`.

## Cloud Run notes

- Cloud Run supplies the `PORT` environment variable automatically; do not set
  `PORT` in `.env`.
- Supply the values from your `.env` file in Cloud Run through **Containers →
  Variables and Secrets**.
- `WEBUI_ADMIN_EMAIL` and `WEBUI_ADMIN_PASSWORD` create the initial administrator
  only when the Open WebUI database is fresh and contains no users.
- This repository intentionally does not configure persistent
  `/app/backend/data` storage. It is designed to be complete on its first run.

## The idea

_Masdan_ means “to look, watch, or observe carefully and closely.” MASDAN-DX
does exactly that at machine speed: Gemini watches the signal, Intel Packs give
it a mission, and the intelligence comes to you.
