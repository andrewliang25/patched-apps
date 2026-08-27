# Contributing

## Signing your commits

Sign your commits to this repo, so that GitHub shows a green **Verified** badge. This repo uses
**SSH commit signing**. You can use the same SSH key that you use to push to GitHub. A GPG
toolchain is not necessary.

> Signing is enabled, but it is **not enforced**, and the repo still accepts unsigned commits.
> Sign your commits anyway. The commits that CI writes on the `update` branch, that is the daily
> version bumps of `github-actions[bot]`, stay unsigned on purpose.

### 1. Configure git to sign with SSH

Run these commands in your clone. To sign in every repo, add `--global` to each command:

```bash
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_rsa.pub   # your public key, of any type (rsa, ed25519)
git config commit.gpgsign true
git config tag.gpgsign true                     # optional. It also signs annotated tags.
```

### 2. Register the key on GitHub as a *Signing Key*

A key that you added for **authentication** cannot sign commits. Add the key again with the
signing type:

```bash
gh ssh-key add ~/.ssh/id_rsa.pub --type signing --title "commit-signing"
```

You can also use **GitHub → Settings → SSH and GPG keys → New SSH key → Key type: _Signing Key_**.

> The `gh ssh-key add --type signing` command needs the `admin:ssh_signing_key` token scope. To
> add it, run `gh auth refresh -h github.com -s admin:ssh_signing_key`, or use the web page above.

### 3. Make sure that GitHub has your commit email as verified

GitHub shows **Verified** only when the committer email of the commit is a **verified email on
the account that owns the signing key** (GitHub → Settings → Emails). If it is not, the signature
stays cryptographically correct, but GitHub shows **Unverified**. Verify that email, or commit
with the `@users.noreply.github.com` address of your account:

```bash
git config user.email <you>@users.noreply.github.com
```

### 4. (Optional) Verify signatures locally

To print *Good signature* on your machine, `git log --show-signature` needs an `allowed_signers`
file. The badge on GitHub does not need this file:

```bash
mkdir -p ~/.config/git
printf '%s namespaces="git" %s\n' "$(git config user.email)" "$(cat ~/.ssh/id_rsa.pub)" \
  >> ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

Then:

```bash
git commit --allow-empty -m "test: signed commit"   # to remove it: git reset --hard HEAD~1
git log --show-signature -1                          # prints: Good "git" signature for <you>
```
