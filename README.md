# masdan-dx

## What is this?

### masdan
n. _to look, watch, or observe, carefully and closely_

Docker app made for notifications using inference and web sources. An OSINT-SIGINT-WEBINT tool. It watches things for you, so you don't have to.

## installation

Clone the repo first and enter the folder:

```bash
git clone https://github.com/elogada/masdan-dx
cd masdan-dx
```

Copy the sample environment variables:
```bash
cp .env.sample .env
```

Edit it as needed by supplying your own keys and credentials. Then build and run:
```bash
docker build -t masdan-dx .
docker run --rm -p 8080:8080 --env-file .env masdan-dx
```

Open `http://localhost:8080`.


## Cloud Run notes

* Cloud Run supplies the `PORT` environment variable automatically; do not set `PORT` in `.env`.
* Make sure to supply your own `.env` file in Cloud Run via the _Containers_ tab, under _Variables and Secrets_
* `WEBUI_ADMIN_EMAIL` + `WEBUI_ADMIN_PASSWORD` create the initial admin only when the Open WebUI database is fresh/no users exist.
* This repository intentionally does not solve persistent `/app/backend/data` storage. It is meant to be complete on first run.