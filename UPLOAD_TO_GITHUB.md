# Upload the final DataPrepOps v2 code to GitHub

Destination: a **new GitHub repository of your choice**, e.g. `https://github.com/YOUR_USERNAME/YOUR_NEW_REPOSITORY`.

**Upload the extracted repository files, not the ZIP as a single GitHub file.** The GitHub clone/commit/push method below preserves hidden `.github`, `.gitignore`, and `.gitattributes` files and keeps folder hierarchy intact. It is safer than dragging files from Finder.

## Recommended: new or empty repository

**Web upload alternative:** On GitHub, create an empty repository, choose *Add file → Upload files*, then drag the **contents** of the extracted `dataprepops` folder (not the ZIP itself). On macOS Finder press **Cmd+Shift+.** to show dotfiles like `.github` and `.gitignore`. Check that the paths stay at the repository root. For reliable hidden-file and folder preservation, use the Git commands below.

```bash
# On Mac, extract the downloaded DataPrepOps_FINAL_Ready_For_GitHub.zip file.
cd ~/Downloads/dataprepops                   # use the actual extracted folder path
# Check for local secrets before committing:
find . -name '*.pem' -o -name '*.tfstate*' -o -name 'terraform.tfvars'
git init
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_NEW_REPOSITORY.git
git add .
git status --short
# Review staged paths before committing.
git commit -m "Add complete DataPrepOps DevSecOps implementation"
git push -u origin main
```

If `git push` reports that the remote already has commits, **do not force-push**. Clone the existing GitHub repository into a separate directory, copy over the new files (excluding any `.git`, `.venv`, Terraform state/variables, credentials), review the diff, commit, and push normally.

## Verify after upload

Open the GitHub URL and confirm at root: `Jenkinsfile`, `.github/`, `app/`, `worker/`, `terraform/`, `ansible/`, `docker/`, `k8s/`, `monitoring/`, `scripts/security/`, `README.md`, `DEMO_GUIDE.md` and `SECURITY.md`. Check GitHub Actions → Python CI to see whether tests pass on GitHub's runner. **Only then** proceed to live AWS deployment in `README.md`.
