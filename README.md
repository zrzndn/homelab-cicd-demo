# Home Lab CI/CD Demo

A small static website that demonstrates this flow:

1. Edit `index.html` on your laptop.
2. `git commit` and `git push` to GitHub's `main` branch.
3. GitHub Actions runs on your self-hosted runner.
4. The workflow validates Compose, rebuilds the Docker image, recreates the container, and checks the website returns HTTP 200.
5. View the app at <http://localhost:8080>.

This starter deploys locally to the same Windows machine that runs Docker Desktop. It is intentionally a first learning project—not a production deployment template.

## Requirements

- Windows 10/11 x64
- Git for Windows
- Docker Desktop using the WSL 2 backend, running Linux containers
- A GitHub account and a **private** GitHub repository

Install Docker Desktop: <https://docs.docker.com/desktop/setup/install/windows-install/>
Install Git: <https://git-scm.com/download/win>

## 1. Test Docker locally first

Open PowerShell in this project folder and run:

```powershell
docker --version
docker compose version
docker compose up -d --build
```

Open <http://localhost:8080>. You should see the demo page.

To stop the local demo before setting up automation:

```powershell
docker compose down
```

## 2. Create an empty private GitHub repository

On GitHub, create a **private** repository named `homelab-cicd-demo`. Do not initialise it with a README, licence, or `.gitignore`, because this folder already contains those files.

In PowerShell, from this project folder, run the following commands. Replace the URL with your own repository URL:

```powershell
git init
git branch -M main
git add .
git commit -m "Create home lab CI/CD demo"
git remote add origin https://github.com/YOUR-USERNAME/homelab-cicd-demo.git
git push -u origin main
```

If the workflow appears as queued while no runner is online, that's expected. It will run when the runner connects.

## 3. Register this computer as a GitHub Actions runner

Keep the repository private and only run workflows you trust on this computer. A self-hosted runner can execute commands on your machine.

1. Open your repository on GitHub.
2. Go to **Settings → Actions → Runners → New self-hosted runner**.
3. Choose **Windows** and **x64**.
4. Follow the current commands shown by GitHub to download and configure the runner. Use a separate folder such as `C:\actions-runner`, not this project folder.
5. When prompted, give the runner a useful name such as `homelab-laptop` and accept the default labels.
6. For this first demo, run `run.cmd` interactively in PowerShell and leave that window open. Do not install it as a service yet.

GitHub provides a short-lived registration token in its setup instructions. Do not share it or paste it into your repository. The runner must stay online, and Docker Desktop must be running.

Official runner instructions: <https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners>

## 4. Experience automated deployment

1. Open `index.html` in an editor.
2. Change `Release: v1 — my first automated deployment` to `Release: v2 — deployed by git push`.
3. Save, then run:

```powershell
git add index.html
git commit -m "Update homepage to release v2"
git push
```

4. On GitHub, open the repository's **Actions** tab and watch the workflow run.
5. When it turns green, refresh <http://localhost:8080> (use Ctrl+F5 if the page looks cached). The release text should say v2.

The workflow performs `docker compose build` and `docker compose up -d --no-build`; you do not manually run Docker commands after each push.

## Troubleshooting

- **`docker` is not recognised / cannot connect:** start Docker Desktop and wait until its engine is ready; re-run `docker info`.
- **Workflow queued / no runner:** make sure `run.cmd` is running and the runner shows `Idle` in **Settings → Actions → Runners**.
- **Port 8080 already in use:** change the left side of `8080:80` in `compose.yaml` (for example, `8081:80`) and also change the URL in the workflow and README.
- **Container is running but the page isn't updated:** confirm your commit reached the `main` branch and the latest Actions run passed; then hard-refresh the page.
- **Need to inspect logs:** run `docker compose ps` and `docker compose logs --tail 100` from the project folder.

## Safety notes

- Use a private repository with only trusted collaborators. Never attach this runner to a public repository or allow untrusted pull-request workflows to execute on it.
- Keep the runner online only while experimenting; stop it with Ctrl+C when you're finished.
- Do not store passwords, access tokens, or other secrets in the repo.
- This example is for learning. Real production deployment needs stronger isolation, access control, approvals, backups, observability, and a rollback plan.
