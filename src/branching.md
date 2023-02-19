# Branching strategy

- [main](https://github.com/microsoft/cloud-hubs/tree/main) includes the latest stable release.
- [dev](https://github.com/microsoft/cloud-hubs/tree/dev) includes the latest changes that will go into the next release.
- Feature branches (`features/<feature-name>`) are used for any in-progress features that are not yet ready for release.
- Personal branches (`<your-github-account>/<feature-name>`) are intended for a single developer and typically not shared. Use these for small changes that can easily be integrated into the next release.

On this page:

- [Tips for external contributors](#tips-for-external-contributors)
- [Tips for Microsoft contributors](#tips-for-microsoft-contributors)

---

## Tips for external contributors

External contributors will always start by forking the repo.

If contributing to an in-progress feature, switch to the feature branch and submit a PR back to the main repo's feature branch.

If contributing a new feature, switch to the `dev` branch and submit a PR back to the main repo's `dev` branch. You are free to invite others to contribute within your fork as needed.

If you run into any issues, please reach out to us on [Discussions](https://github.com/microsoft/cloud-hubs/discussions). We're happy to help!

<br>

## Tips for Microsoft contributors

If planning a new feature that will require work from multiple developers (Microsoft or external), create a feature branch.

We encourage all developers to submit PRs against feature branches to ensure everyone is on the same page with what's committed and avoid breaking each other. This is optional and not enforced however.

If working on a single-commit change, you are free to create a personal dev branch (`<your-github-account>/<feature-name>`) and submit a PR from there.

Note that all branches are automatically deleted after a PR is merged to `dev`.

<br>
