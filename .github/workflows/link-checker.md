---
description: Weekday automated link checker that scans FinOps Toolkit documentation for broken links, finds replacements, and opens draft pull requests against dev.
on:
  schedule: daily on weekdays
  workflow_dispatch:
  skip-if-match:
    query: 'is:pr is:open "gh-aw-workflow-id: link-checker" in:body'
    max: 1
permissions:
  contents: read
  issues: read
  pull-requests: read
  copilot-requests: write
timeout-minutes: 60
engine:
  id: copilot
  copilot-sdk: true
network:
  allowed:
    - defaults
    - node
    - python
    - github
    - powershell
    - aka.ms
    - learn.microsoft.com
    - docs.microsoft.com
    - azure.microsoft.com
    - go.microsoft.com
    - techcommunity.microsoft.com
    - devblogs.microsoft.com
    - microsoft.github.io
    - azure.github.io
    - portal.azure.com
    - finops.org
    - www.finops.org
    - focus.finops.org
    - learn.finops.org
steps:
  - name: Check and test all documentation links
    id: link-check
    run: |
      mkdir -p /tmp/gh-aw/agent
      echo "# Link Check Results" > /tmp/gh-aw/agent/link-check-results.md
      echo "" >> /tmp/gh-aw/agent/link-check-results.md
      
      # Find all markdown files in FinOps Toolkit documentation directories and README
      echo "Finding all markdown files..."
      MARKDOWN_FILES=$(find docs docs-mslearn docs-wiki README.md -type f -name "*.md" 2>/dev/null || echo "")
      
      if [ -z "$MARKDOWN_FILES" ]; then
        echo "No markdown files found"
        echo "no_files=true" >> $GITHUB_OUTPUT
        exit 0
      fi
      
      # Extract all links from markdown files
      echo "## Links Found" >> /tmp/gh-aw/agent/link-check-results.md
      echo "" >> /tmp/gh-aw/agent/link-check-results.md
      
      # Single-pass parser: extract Markdown destinations once (preserving balanced parentheses),
      # mask matched Markdown link spans, and then extract bare HTTP(S) URLs.
      find docs docs-mslearn docs-wiki README.md -type f -name "*.md" -print0 2>/dev/null | python3 -c '
      import re, sys

      def extract_urls(text):
          urls = []
          spans_to_mask = []
          i = 0
          n = len(text)
          while i < n:
              idx = text.find("](", i)
              if idx == -1:
                  break
              line_start = text.rfind("\n", 0, idx) + 1
              if "[" not in text[line_start:idx]:
                  i = idx + 2
                  continue
              j = idx + 2
              while j < n and text[j] in " \t":
                  j += 1
              if j < n and text[j] == "<":
                  end_angle = text.find(">", j + 1)
                  if end_angle != -1:
                      url = text[j + 1:end_angle].strip()
                      close_paren = text.find(")", end_angle + 1)
                      if close_paren != -1:
                          if url.startswith(("http://", "https://")):
                              urls.append(url)
                          spans_to_mask.append((idx, close_paren + 1))
                          i = close_paren + 1
                          continue
              depth = 0
              k = j
              while k < n and text[k] not in " \t\r\n":
                  if text[k] == "(":
                      depth += 1
                  elif text[k] == ")":
                      if depth == 0:
                          break
                      depth -= 1
                  k += 1
              url = text[j:k]
              m = k
              while m < n and text[m] != "\n":
                  if text[m] == ")":
                      if depth == 0:
                          break
                      depth -= 1
                  elif text[m] == "(":
                      depth += 1
                  m += 1
              if m < n and text[m] == ")":
                  if url.startswith(("http://", "https://")):
                      urls.append(url)
                  spans_to_mask.append((idx, m + 1))
                  i = m + 1
              else:
                  i = idx + 2

          # Match reference-style link definitions: [label]: url "optional title"
          for m in re.finditer(r"(?m)^\s*\[[^\]]+\]:\s*<?(https?://[^\s>\"\x27]+)>?", text):
              urls.append(m.group(1))
              spans_to_mask.append((m.start(1), m.end(1)))

          chars = list(text)
          for s, e in spans_to_mask:
              for p in range(s, e):
                  chars[p] = " "
          masked = "".join(chars)

          for m in re.finditer(r"https?://[^\s<>\"`\]]+", masked):
              raw = m.group(0)
              while raw:
                  if raw[-1] in ".,;:!?\x27":
                      raw = raw[:-1]
                  elif raw[-1] == ")" and raw.count(")") > raw.count("("):
                      raw = raw[:-1]
                  else:
                      break
              if raw.startswith(("http://", "https://")):
                  urls.append(raw)
          return urls

      files = [f for f in sys.stdin.read().split("\0") if f]
      with open("/tmp/gh-aw/agent/all-links.txt", "w", encoding="utf-8") as out:
          for path in files:
              print(f"Checking {path}...")
              try:
                  with open(path, encoding="utf-8", errors="ignore") as fh:
                      for u in extract_urls(fh.read()):
                          out.write(u + "\n")
              except OSError:
                  pass
      '
      
      # Remove duplicates and sort
      if [ -s /tmp/gh-aw/agent/all-links.txt ]; then
        sort -u /tmp/gh-aw/agent/all-links.txt > /tmp/gh-aw/agent/unique-links.txt
        LINK_COUNT=$(wc -l < /tmp/gh-aw/agent/unique-links.txt)
        echo "Found $LINK_COUNT unique links" >> /tmp/gh-aw/agent/link-check-results.md
        echo "" >> /tmp/gh-aw/agent/link-check-results.md
      else
        echo "No links found" >> /tmp/gh-aw/agent/link-check-results.md
        echo "no_links=true" >> $GITHUB_OUTPUT
        exit 0
      fi
      
      # Test each link
      echo "## Link Test Results" >> /tmp/gh-aw/agent/link-check-results.md
      echo "" >> /tmp/gh-aw/agent/link-check-results.md
      echo "Testing links..." >> /tmp/gh-aw/agent/link-check-results.md
      
      BROKEN_COUNT=0
      WORKING_COUNT=0
      
      while IFS= read -r url; do
        # Skip relative links, localhost, and placeholder URLs
        if [[ "$url" == "#"* ]] || [[ "$url" != "http"* ]] || [[ "$url" == *"localhost"* ]] || [[ "$url" == *"example.com"* ]]; then
          continue
        fi
        
        # Test the link with curl
        HTTP_CODE=$(curl -L -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
        
        if [[ "$HTTP_CODE" =~ ^2 ]] || [[ "$HTTP_CODE" =~ ^3 ]]; then
          WORKING_COUNT=$((WORKING_COUNT + 1))
          echo "✅ $url (HTTP $HTTP_CODE)" >> /tmp/gh-aw/agent/link-check-results.md
        else
          BROKEN_COUNT=$((BROKEN_COUNT + 1))
          echo "❌ $url (HTTP $HTTP_CODE)" >> /tmp/gh-aw/agent/link-check-results.md
        fi
      done < /tmp/gh-aw/agent/unique-links.txt
      
      echo "" >> /tmp/gh-aw/agent/link-check-results.md
      echo "**Summary:** $WORKING_COUNT working, $BROKEN_COUNT broken" >> /tmp/gh-aw/agent/link-check-results.md
      
      # Output results
      echo "broken_count=$BROKEN_COUNT" >> $GITHUB_OUTPUT
      echo "working_count=$WORKING_COUNT" >> $GITHUB_OUTPUT
      
      cat /tmp/gh-aw/agent/link-check-results.md
    shell: bash

tools:
  github:
    toolsets: [default]
  cache-memory: true
  web-fetch:

safe-outputs:
  create-pull-request:
    title-prefix: "[link-checker] "
    base-branch: "dev"
    labels:
      - "Type: Documentation 📃"
      - "Skill: Documentation"
      - "Micro PR 🔬"
      - "Status: Autopilot 🤖"
    draft: true
    max: 1
    allowed-files:
      - "docs/**/*.md"
      - "docs-mslearn/**/*.md"
      - "docs-wiki/**/*.md"
      - "README.md"
    protected-files: fallback-to-issue
    if-no-changes: "warn"
  noop:
source: githubnext/agentics/workflows/link-checker.md@b4e175bab6674279e0fe158f7dc877b77bc9d92f
---

# Daily Link Checker & Fixer

You are an automated link checker and fixer agent. Your job is to find and fix broken links in the documentation files of this repository.

## Your Mission

Your workflow has already collected and tested all links in the previous step. Use the test results to identify broken links and fix them where possible.

## Step 1: Review Link Check Results

The link check step has already run and created a report at `/tmp/gh-aw/agent/link-check-results.md`. Read this file to see:
- All links found in the documentation
- Which links are working (✅) and which are broken (❌)
- HTTP status codes for each link

Use bash to read the file:
```bash
cat /tmp/gh-aw/agent/link-check-results.md
```

## Step 2: Load Cache Memory

Check cache memory for previously identified unfixable broken links:
- Load the cache memory to see if there are any broken links we've tried to fix before but couldn't
- These are links that are permanently broken or removed from the internet
- Skip these links to avoid repeated attempts

The cache memory should store a JSON object with this structure:
```json
{
  "unfixable_links": [
    {
      "url": "https://example.com/removed-page",
      "reason": "404 Not Found - content removed",
      "first_seen": "2026-02-17"
    }
  ],
  "last_run": "2026-02-17"
}
```

## Step 3: Research and Fix Broken Links

For each broken link found in the test results (but NOT in the unfixable list):

1. **Investigate the link:**
   - Determine what the link was supposed to point to based on:
     - The link text in the markdown
     - The context around the link
     - The surrounding documentation
   
2. **Search for alternatives:**
   - Use web-fetch to search for if the content has moved to a new URL (note: `web-fetch` runs behind the workflow firewall and can only reach allowlisted documentation domains such as `aka.ms`, `learn.microsoft.com`, `azure.microsoft.com`, `github.com`, and `finops.org`; if `web-fetch` cannot reach a non-allowlisted third-party host, rely on the pre-step curl HTTP status in `/tmp/gh-aw/agent/link-check-results.md` and do not treat a firewall block as a broken link)
   - Try common alternatives (www vs non-www, http vs https, with/without trailing slash)
   - Look for redirects or updated documentation
   - Check if there's an official replacement
   
3. **Fix the link:**
   - If you find a working replacement URL, use the `edit` tool to update the markdown file
   - Replace the broken URL with the working one
   - Make sure to preserve the link text and formatting
   - If you modify the body content of any file under `docs-mslearn/**/*.md`, also update its `ms.date` YAML frontmatter field to today's date (`MM/DD/YYYY`) per `AGENTS.md`
   
4. **Document unfixable links:**
   - If a link truly cannot be fixed (content permanently removed, no alternatives found):
     - Add it to the unfixable_links list in cache memory
     - Include the URL, reason, and date
     - This prevents future runs from wasting time on the same broken link

## Step 4: Update Cache Memory

After processing all broken links:
- Update the cache memory with any new unfixable links
- Update the "last_run" timestamp
- Save the updated cache memory

## Step 5: Create Pull Request or Noop

Based on your work:

**If you fixed any links:**
- Use the `create-pull-request` safe output to create a PR with your fixes
- In the PR body, include:
  - A summary of how many links were fixed
  - A list of the broken links and their replacements
  - Any links that were added to the unfixable list
- Title format: "Fix broken documentation links"

**If no links needed fixing:**
- Use the `noop` safe output with a clear message like:
  - "All documentation links are working correctly" (if no broken links found)
  - "All broken links are in the unfixable list, no new fixes available" (if broken links exist but can't be fixed)

## Important Guidelines

- **Be thorough:** Check every broken link carefully
- **Preserve context:** When replacing links, make sure the new URL points to equivalent or better content
- **Document everything:** Keep the cache memory up to date with unfixable links
- **Be selective:** Only add links to the unfixable list if you've genuinely tried to find alternatives
- **Use web-fetch wisely:** Try to fetch the broken URL and check for redirects or alternatives
- **Relative links:** Focus only on HTTP(S) links. Skip relative links and anchors (they're tested differently)

## Example Cache Memory Update

```json
{
  "unfixable_links": [
    {
      "url": "https://old-docs.example.com/api/v1",
      "reason": "Documentation site shut down, no replacement found despite searching",
      "first_seen": "2026-02-17"
    }
  ],
  "last_run": "2026-02-17"
}
```

## Context

- Repository: `${{ github.repository }}`
- Run daily on weekdays to catch broken links early
- Link test results are available at `/tmp/gh-aw/agent/link-check-results.md`
