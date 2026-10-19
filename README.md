# Home Lab CI/CD — Advanced Upgrade

This upgrade adds a realistic learning workflow to the original Windows + Docker Desktop demo:

1. **Automated tests** run before Docker is built. A failed test blocks deployment.
2. **Immutable version tags** use `sha-<12-character-git-commit>` rather than overwriting one `latest` image tag.
3. **Security checks** scan repository content for likely secrets and the built image for fixable CRITICAL package vulnerabilities using Trivy.
4. **Health checks and rollback** verify the HTTP page, `/health`, expected release tag, and Docker's health status. If a new release fails and a previous local release exists, the deployment script tries to restore it.
5. **Separate environments:** every push to `main` deploys to staging on port 8081. Production runs separately on port 8082 and is promoted manually from GitHub Actions.
6. **Basic monitoring** polls staging and production HTTP status, response time and container state.

This is a local learning lab—not a production-ready deployment blueprint. The staging and production services both run on your laptop, and rollback relies on older image tags still being present in its Docker image store.

## Upgrade the project you already pushed

1. Keep your existing project folder and its `.git` directory. Do **not** delete `.git` and do not run `git init` again.
2. Extract this ZIP into a temporary folder.
3. Copy the extracted files and folders into your existing `homelab-cicd-demo` folder, allowing the supplied files to replace matching files. This bundle intentionally does not contain `.git`.
4. Make sure Docker Desktop is running in Linux-container mode and that your self-hosted runner can use the same Docker engine.
5. From your existing repository folder, open PowerShell and run:

   ```powershell
   .\scripts\Test-Website.ps1
   docker compose config --quiet
   ```

6. Commit and push the upgrade:

   ```powershell
   git add .
   git commit -m "Upgrade CI/CD with tests security and rollback"
   git push
   ```

The current legacy demo on port 8080 is intentionally left alone. The upgraded workflow uses staging `http://localhost:8081` and production `http://localhost:8082` so you can compare them side-by-side safely.

## What runs automatically on every push to `main`

The self-hosted runner executes this pipeline:

1. PowerShell source tests.
2. Docker Compose configuration validation.
3. Build a Docker image tagged like `homelab-cicd-demo-web:sha-0123456789ab`.
4. Trivy source dependency/secret scan.
5. Trivy image scan that blocks fixable CRITICAL vulnerability findings.
6. Deploy to staging, then check the page, `/health`, release tag and Docker health status.
7. If the new staging release fails its health checks, attempt to restore the previous successful local staging tag.

The Trivy scanner image is pinned to version `0.76.0`. Its first invocation downloads the scanner and vulnerability database, so the first security scan may take longer than later runs. An image scan may block deployment if it detects a fixable CRITICAL finding; inspect the scan report instead of disabling the check blindly.

This sample application is a static HTML page with no application package manager or third-party code libraries. The image scan covers OS/runtime packages in the Nginx base image; expand the dependency scan if you add npm, Python, .NET or other application dependencies.

## Deploy to production manually

After a push succeeds and staging works:

1. Open the repository on GitHub → **Actions**.
2. Select **Home Lab CI-CD (test, scan, stage, promote, rollback)**.
3. Select **Run workflow**.
4. Choose `production` as the target and run it.

The workflow tests, builds and scans the selected commit again, then deploys it on port 8082. Staging remains on 8081. This is a manual promotion for practice; a real environment should also have production access controls and an approval policy.

## Try proving the test gate works

In `index.html`, temporarily change the title from:

```html
<title>Home Lab CI/CD Demo</title>
```

to:

```html
<title>Intentionally broken title</title>
```

Commit and push the change. The automated test should fail before image build/deployment, leaving the previously deployed staging version running. Then restore the original title, commit and push again.

## Find your image versions and roll back production

List image tags kept locally:

```powershell
docker image ls homelab-cicd-demo-web
```

Tags look like `sha-0123456789ab`. To roll production back:

1. Open **Actions → Home Lab CI-CD (test, scan, stage, promote, rollback) → Run workflow**.
2. Choose `rollback-production`.
3. Enter an existing image tag in `image_tag`, for example `sha-0123456789ab`.
4. Run the workflow and confirm the health checks pass at `http://localhost:8082`.

The rollback target must already exist in the local Docker image store on the runner. Avoid deleting older tags until you no longer need them. The app records the last successful tag in `%USERPROFILE%\.homelab-cicd-demo\deploy-state\` outside the Git workspace.

## Monitoring and troubleshooting

Run a one-time status check:

```powershell
.\scripts\Monitor.ps1 -Once
```

Keep polling every five seconds:

```powershell
.\scripts\Monitor.ps1
```

Press `Ctrl+C` to stop. More useful checks:

```powershell
docker compose -p homelab-staging ps
docker compose -p homelab-staging logs --tail 100
docker compose -p homelab-production ps
docker compose -p homelab-production logs --tail 100
docker stats
```

- **Runner offline / workflow queued:** leave `C:\actions-runner\run.cmd` running, and keep Docker Desktop open.
- **Secret scan flags a file:** inspect the path and remove secrets from the repository. Rotate a credential if it was ever committed; deleting a file in a later commit does not remove it from history.
- **Image scan fails:** inspect the Trivy output. Update the vulnerable base/runtime package or image where appropriate and rerun the pipeline.
- **Deployment health check fails:** the script displays recent Compose logs and attempts rollback. If rollback itself fails, inspect the named project's logs and container status.
- **Port conflict:** this lab intentionally uses 8081 for staging and 8082 for production; the old demo can continue to use 8080.

## Safety notes

- Keep the repository private and do not run untrusted workflows on your self-hosted runner. Actions code can execute commands on your Windows account.
- Do not commit tokens, passwords or private keys.
- No app port is exposed publicly by this lab; the services listen on local host ports.
- The scanner's policy here blocks fixable CRITICAL image findings, not every CVE. Review all findings and tune policy thoughtfully as you learn.
- The `latest` image tag is not used for releases; commit-specific tags are intended to make versions identifiable and rollback-able.
