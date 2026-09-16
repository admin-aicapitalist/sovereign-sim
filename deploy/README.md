# Public hosting

Play: **https://sovereign-432652279722.us-central1.run.app/**

The Godot browser export runs on the existing `sovereign` Cloud Run service in `us-central1`, project `aiprocessor-468717`, using the personal `synergy` gcloud configuration.

The character art release was deployed on 2026-09-16 as revision
`sovereign-00011-8gs`, serving 100% of traffic. Its game pack has SHA-256
`79e26a633587317e788e4c91539475ba0979e0bc9f3c4a3f1df4ddb41f022666`.
The preceding Royal art release is `sovereign-00010-rr2`; the earlier Godot
release is `sovereign-00009-v56`. See [character verification](../godot/reports/CHARACTERS.md).

The service uses 1 CPU, 128 MiB memory, zero minimum instances, two maximum instances, and the existing `sovereign-web@aiprocessor-468717.iam.gserviceaccount.com` runtime account. Public access uses the disabled Invoker IAM check. The container serves static files on port 8080; gameplay runs in the player's browser.

## Deploy

From the repository root, export with Godot and matching web templates:

```sh
python3 godot/tools/export_web.py --godot /path/to/Godot
```

See [Godot setup](../godot/README.md#browser-build) for the local engine and template paths. Then deploy the **Godot directory**:

```sh
gcloud --configuration=synergy --project=aiprocessor-468717 run deploy sovereign \
  --source=godot --region=us-central1 \
  --no-invoker-iam-check --ingress=all \
  --service-account=sovereign-web@aiprocessor-468717.iam.gserviceaccount.com \
  --port=8080 --memory=128Mi --cpu=1 \
  --min=0 --max=2 --concurrency=80 --timeout=30 --quiet
```

Godot's `.gcloudignore` and `.dockerignore` include only the browser export and container configuration. Nginx serves precompressed WASM, game data and JavaScript with the correct MIME types and a 60-second cache lifetime. The root Dockerfile belongs to the earlier JavaScript prototype; `--source=godot` selects the full port. Cloud Run builds this directory's Dockerfile through its [source deployment flow](https://docs.cloud.google.com/run/docs/deploying-source-code).

## Verify

With a test Chrome instance listening on port 9231:

```sh
GODOT_HOSTING_URL=https://sovereign-432652279722.us-central1.run.app/ \
  GODOT_REPORTS_DIR=/tmp/sovereign-godot-deployed \
  node godot/tests/hosting.mjs
GODOT_TEST_URL=https://sovereign-432652279722.us-central1.run.app/ \
  GODOT_REPORTS_DIR=/tmp/sovereign-godot-deployed GODOT_SKIP_BENCH=1 \
  node godot/tests/browser.mjs
```

Hosting checks compare downloaded files with the local export, including gzip delivery, WASM MIME, `/health` and missing-file responses. The health endpoint avoids Cloud Run's [reserved URL paths](https://docs.cloud.google.com/run/docs/known-issues#reserved-url-paths). Browser checks exercise gameplay, saves, endings, mobile controls and normal startup. Godot saves have a different format from the earlier JavaScript game's saves.

## Roll back

To restore the previous Godot release:

```sh
gcloud --configuration=synergy --project=aiprocessor-468717 run services update-traffic sovereign \
  --region=us-central1 --to-revisions=sovereign-00010-rr2=100 --quiet
```

After any rollback, use `--to-latest` with the same command to return traffic to the latest deployed revision when ready.

The older JavaScript prototype is retained as revision `sovereign-00007-tpc`.
