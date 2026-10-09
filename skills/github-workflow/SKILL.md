---
name: github-workflow
description: Git and GitHub conventions for branches, commits, PRs, and releases. Use when changing code in a Git repository, branching, committing, writing commit or PR messages, merging a PR, or tagging a release.
---

# GitHub Workflow

If the repository has its own conventions, follow them. Otherwise, use these defaults.

## Principles
- Keep all communication concise. Write only what is necessary. Remove filler, repetition, and obvious explanations.
- Follow the engineering taste of Linus Torvalds: simplicity, clarity, correctness, and maintainability.

## Branches
- Keep `main` protected. Make changes on short-lived branches such as `feat/`, `fix/`, `refactor/`.
- Prefer trunk-based development: merge small changes into `main` often. Avoid a permanent `develop` branch.

## Commits
- Commit in small steps during development, not only at the end.
- Follow Conventional Commits: `type(scope): imperative summary`.
- Make each commit one logical, self-contained change.
- When possible, make sure that each commit builds and passes the tests. This rule lets `git bisect` test every commit.
- Write a concise, precise subject line, ideally 72 characters or fewer.
- Add a body only when it is necessary to explain the motivation, a non-obvious decision, or a consequence.
- Explain why. Do not repeat what the diff already shows.
- Do not write wordy narratives, generic summaries, or unnecessary bullet lists.
- You can rewrite your own unmerged branch. Push the rewritten branch with `--force-with-lease`.

## Pull Requests
- Put one focused change in each PR.
- Use the Conventional Commits format for the PR title.
- Keep the PR description concise and minimal: **why, what, tests**. Do not include anything obvious or not applicable.
- If relevant, state important trade-offs, breaking changes, or limitations.
- Do not write boilerplate, self-congratulation, implementation diaries, or redundant file-by-file descriptions.
- Open the PR as a draft early, so that each feature branch has an associated PR.
- Push review fixes as fixup commits (`git commit --fixup`). Before the merge, use `git rebase --autosquash` to combine each fixup commit with the commit that it fixes.
- Use **Rebase and merge** to keep atomic commits on `main`. If the whole PR is one logical change, use **Squash and merge**.
- Delete the branch after the merge.

## Releases
- Use Semantic Versioning.
- When practical, automate the changelog and GitHub Releases.
- Create a release branch only to stabilize or maintain a release for larger projects.
- Merge each fix into `main` first. If a release branch also needs the fix, cherry-pick it to that branch.
