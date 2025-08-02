# GitHub Copilot instructions for FinOps toolkit

## 🎯 Repository overview

This is the Microsoft FinOps toolkit - an open-source collection of tools and resources that help organizations learn, adopt, and implement FinOps capabilities in the Microsoft Cloud. The toolkit includes starter kits, scripts, advanced solutions, workbooks, and FinOps hubs for cost optimization and management.

## 🛡️ Core principles

### Quality standards

- **Documentation first**: Document everything with inline comments and READMEs
- **Zero lint errors**: Resolve all lint errors before suggesting changes
- **Test coverage**: Ensure changes don't break existing functionality
- **Microsoft standards**: Follow Microsoft style guide and development practices
- **Document changes**: Always document changes in the [changelog](../docs-mslearn/toolkit/changelog.md)
  - Changelog entries must be under the correct tool and version (e.g., FinOps hubs v12)
  - Check the current version in [package.json](../package.json)
  - Remove `-dev` from the version, if included
  - For releases, include download and changelog links at the end of each release section using the format:
    ```markdown
    > [!div class="nextstepaction"]
    > [Download](https://github.com/microsoft/finops-toolkit/releases/tag/vX)
    > [!div class="nextstepaction"]
    > [Full changelog](https://github.com/microsoft/finops-toolkit/compare/vX-1...vX)
    ```

### Code style guidelines

- Follow existing code patterns and conventions in each language
- Use sentence casing, not Title Casing (except for product names)
- Be brief and clear - "bigger ideas, fewer words"
- Write like you speak - project friendliness
- Avoid end punctuation on titles, headings, and short list items

## 📁 Repository structure

- `/src/` - Source code for all toolkit components
- `/docs/` - Public website and deployment templates  
- `/docs-wiki/` - Developer guidelines and project documentation
- `/docs-mslearn/` - Microsoft Learn documentation content
- `/.github/` - GitHub workflows, templates, and configuration

## 🔧 Development guidelines

### Before making changes

1. **Read the relevant documentation** in README.md file in each folder or parent folder
2. **Understand the existing patterns** in the codebase that are documented in the docs-wiki folder
3. **Check for existing tests** and maintain test coverage
4. **Add new unit and integration tests** and always improve scenario coverage

### Code quality requirements

- Install recommended VS Code extensions for auto-formatting
- Every folder should have a README.md file
- Add inline comments to all major code blocks
- Follow language-specific conventions:
  - [PowerShell guidelines](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
  - [Bicep lint rules](https://learn.microsoft.com/azure/azure-resource-manager/bicep/linter)

### Content standards (Microsoft style guide)

- Use bigger ideas, fewer words
- Write like you speak
- Project friendliness
- Get to the point fast
- Be brief
- When in doubt, don't capitalize
- Always use sentence casing, not Title Casing
- Avoid end punctuation on titles, headings, subheads, UI titles
- Remember the last comma (Oxford comma)
- Don't be spacey
- Revise weak writing

## 🚀 Common tasks

### Adding new features

- Create feature branches for multi-developer work
- Submit PRs to `dev` branch with complete, validated changes
- Update applicable documentation in `/docs/`
- Cover external-facing changes in changelog

### Bug fixes

- Focus on minimal, surgical changes
- Maintain existing functionality
- Add or update tests to prevent regressions
- Document the fix clearly

### Documentation updates

- Keep documentation inline with code when possible
- Update README files when adding new components
- Follow Microsoft style guide for all content
- Use consistent formatting and structure

## 🎯 Specific areas

### FinOps tools & solutions

- Follow FinOps Framework principles and terminology
- Ensure solutions work across Azure environments
- Consider scalability and enterprise requirements

### PowerShell development

- Follow PowerShell cmdlet development guidelines
- Use approved verbs and consistent parameter naming
- Include comprehensive help documentation
- Support pipeline input where appropriate

### Bicep templates

- Follow Bicep linting rules and best practices
- Use consistent naming conventions
- Include parameter descriptions and constraints
- Test deployments thoroughly

### Workbooks & queries

- Focus on actionable insights and clear visualizations
- Use consistent query patterns and naming
- Document data sources and calculations
- Ensure compatibility with different Azure environments

## ❌ Avoid these mistakes

- Don't guess at data schemas or API formats
- Don't break existing functionality with changes
- Don't ignore linting errors or warnings
- Don't use Title Case for regular headings
- Don't create partial or incomplete implementations
- Don't skip documentation updates
- Don't submit PRs with merge conflicts

## 📚 Key resources

- [FinOps Framework](https://www.finops.org/framework/)
- [Microsoft FinOps documentation](https://learn.microsoft.com/cloud-computing/finops/)
- [Microsoft Style Guide](https://docs.microsoft.com/style-guide/welcome)
- [Repository wiki](https://github.com/microsoft/finops-toolkit/wiki)
- [Coding guidelines](docs-wiki/Coding-guidelines.md)
- [Branching strategy](docs-wiki/Branching-strategy.md)

## 🤝 Collaboration

- Engage with the community through GitHub Discussions
- Follow the contributor guidelines and code of conduct
- Submit detailed PRs with clear descriptions
- Be responsive to feedback and iterate on suggestions
- Help maintain the high quality standards of the toolkit

Remember: This toolkit helps organizations optimize cloud costs and implement FinOps best practices. Every contribution should advance those goals while maintaining the highest standards of quality and usability.
