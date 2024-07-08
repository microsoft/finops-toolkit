# 🛠️ FinOps toolkit source

**Welcome aboard!** 👋 If this is your first time to our repo, here are a few tips:

- Every folder has a README that explains its purpose.
- If you want to know how to deploy a FinOps toolkit solution, start with the [documentation](https://aka.ms/finops/toolkit).
- If you want to know how you can contribute, check out the [contribution guide](../CONTRIBUTING.md).
- If you want to contribute and need to get started with the code, start in the [wiki](https://github.com/microsoft/finops-toolkit/wiki).
- If you're looking for code, you're in the right place. &nbsp; **← YOU ARE HERE**
  <br>...but check the wiki to get on the right branch, understand the folder structure, and learn how to build and deploy.

<br>

On this page:

- [⚡ Quickstart guide](#-quickstart-guide)

---

## ⚡ Quickstart guide

1. ⬇️ Install Azure PowerShell and the Bicep CLI. [Visual Studio Code](https://code.visualstudio.com) is recommended.
2. ▶️ Start in the `dev` branch (or applicable [feature branch](../docs-wiki/Branching-strategy.md#-important-branches)).
3. 👩‍💻 Make your change and build/deploy using local dev scripts:

  ```powershell
   Set-Location "<root>/src/scripts"  # run from the scripts folder
   ./Deploy-Toolkit "<template-or-module-name>" -Build
  ```

4. 📝 Update [docs](../docs) and the [changelog](../docs/_resources/changelog.md).
5. ✅ Submit a PR and address feedback daily.
6. 🎉 Celebrate! You're done!

For more details, refer to the [dev docs](https://github.com/microsoft/finops-toolkit/wiki) in the wiki.

<br>

# 🙏 Thank you! <!-- markdownlint-disable-line single-h1 -->

Thanks for contributing to the FinOps toolkit!

Let us know if there's anything we can do to streamline the contribution process. Like a good FinOps team, we're always looking for ways to optimize 😉
