# Public hosting

Play: **https://sovereign-432652279722.us-central1.run.app/**

- Personal gcloud configuration: `synergy` (the shell's `personal` alias).
- GCP project: `aiprocessor-468717`.
- Cloud Run service: `sovereign`, region `us-central1`.
- Runtime service account: `sovereign-web@aiprocessor-468717.iam.gserviceaccount.com`, with no project roles granted by this deployment.
- Resources: 1 CPU, 128 MiB memory, zero minimum instances, two maximum instances.
- Public access uses Cloud Run's disabled Invoker IAM check; the organization’s domain-restricted IAM policy is unchanged.
- Nginx serves the static game on port 8080. `.gcloudignore` and `.dockerignore` restrict the deployment to game files and container configuration.

From the project root, deploy updates with:

```sh
gcloud --configuration=synergy --project=aiprocessor-468717 run deploy sovereign \
  --source=. --region=us-central1 \
  --no-invoker-iam-check --ingress=all \
  --service-account=sovereign-web@aiprocessor-468717.iam.gserviceaccount.com \
  --port=8080 --memory=128Mi --cpu=1 \
  --min=0 --max=2 --concurrency=80 --timeout=30 --quiet
```

The game still runs locally by opening `index.html`; Docker and GCP are only used for hosting.

To run the existing browser checks against the hosted site, start a test Chrome instance with remote debugging on port 9227, then:

```sh
SOVEREIGN_TEST_URL=https://sovereign-432652279722.us-central1.run.app/ node test/browser.mjs
```
