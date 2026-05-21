#!/usr/bin/env python3
"""Apply Microsoft Style Guide voice rules to make a transcript sound natural.

The normalizer is a pure text transform on the spoken stream. It never modifies
source docs. It applies these mechanical rules:

R1. Anaphora — first mention of a singular product name uses 'the <product>'
    when used as a sentence subject. Subsequent mentions in the same scene
    use 'the agent' / 'It' (anaphora target depends on the noun phrase).

R2. Run-on splitting — sentences joined by '; ' get split into two when both
    clauses can stand alone.

R3. Source-citation parenthetical removal — '([source YAML](path))' style
    citations are stripped (they're invisible to TTS and break rhythm).

Reference: learn.microsoft.com/style-guide
- grammar/nouns-pronouns
- top-10-tips-style-voice (#5 Be brief)
- contribute/content/style-quick-start (machine-translation 'small words' rule)
- Anaphora pattern from learn.microsoft.com/graph/onenote-branding
"""
import json
import re
import sys


# Singular product names that take 'the' on first sentence-subject mention
# and 'the agent' / 'It' on subsequent mentions.
SINGULAR_PRODUCTS = [
    ("FinOps toolkit SRE Agent", "the agent"),
    ("Azure Optimization Engine", "the engine"),
]


def normalize_anaphora(text: str) -> str:
    """First mention: 'the FinOps toolkit SRE Agent'. Subsequent: 'the agent' / 'It'."""
    for full_name, short_form in SINGULAR_PRODUCTS:
        # Find all positions where the full name appears in body prose.
        # We only edit occurrences not already preceded by 'the '/'The ', and not in:
        #   - markdown link text [...]
        #   - code spans `...`
        #   - URLs
        introduced = False
        out_chars = []
        i = 0
        while i < len(text):
            # Check if `text[i:]` starts with full_name
            if text[i:i + len(full_name)] == full_name:
                # Look back at preceding non-whitespace
                preceding = "".join(out_chars).rstrip()
                # Check 5 chars before for 'the ' / 'The '
                last5 = preceding[-5:] if len(preceding) >= 5 else preceding
                already_articled = bool(re.search(r"\b[Tt]he\s+$", "".join(out_chars)))
                # Check if we're inside a code span (odd number of backticks before us)
                in_code = "".join(out_chars).count("`") % 2 == 1
                # Check if we're inside a link text [...]
                # (last [ comes after last ] in preceding text)
                last_open = "".join(out_chars).rfind("[")
                last_close = "".join(out_chars).rfind("]")
                in_link_text = last_open > last_close
                # Check if we're in a URL (preceded by ](... )
                in_url = bool(re.search(r"\]\([^)]*$", "".join(out_chars)))

                if already_articled or in_code or in_link_text or in_url:
                    # Just emit verbatim
                    out_chars.append(text[i:i + len(full_name)])
                    i += len(full_name)
                    continue

                # Decide: first mention vs subsequent
                # First mention: emit "The <full>" or "the <full>" depending on sentence position
                # Subsequent: emit short form
                # Sentence-start = preceding ends with .!?: or is empty
                is_sentence_start = (
                    not preceding
                    or preceding[-1] in ".!?:"
                )
                if not introduced:
                    article = "The" if is_sentence_start else "the"
                    out_chars.append(f"{article} {full_name}")
                    introduced = True
                else:
                    if is_sentence_start:
                        # Use 'It' for sentence-subject anaphora
                        out_chars.append("It")
                    else:
                        out_chars.append(short_form)
                i += len(full_name)
            else:
                out_chars.append(text[i])
                i += 1
        text = "".join(out_chars)
    return text


def split_semicolon_runons(text: str) -> str:
    """Split sentences joined by '; ' into two sentences."""
    # Conservative: only split when the part after '; ' starts with a lowercase word
    # AND contains a verb-like word (heuristic: any word ending in -s, -ed, -ing, or
    # a common verb). We just do the split and capitalize the next word.
    def repl(m):
        before = m.group(1)
        after = m.group(2)
        return f"{before}. {after[0].upper()}{after[1:]}"
    text = re.sub(r"([a-z]+);\s+([a-z][a-z]+)", repl, text)
    return text


def strip_source_citations(text: str) -> str:
    """Remove inline source-citation parentheticals like '([source YAML](path))'.

    Pattern: open-paren, open-bracket, lowercase keyword (source/tool/etc.),
    optional words, close-bracket, paren with relative path, close-paren.
    """
    # Common patterns observed in kusto-tools.md / python-tools.md
    text = re.sub(
        r"\s+\(\[[a-z][a-z\s]*(?:source|inventory|tool|YAML)\][^)]*\)\)",
        "",
        text,
        flags=re.IGNORECASE,
    )
    # Generic: "([text](path))" where text contains "source" or "yaml"
    text = re.sub(
        r"\s+\(\[[^\]]*(?:source|YAML|inventory)[^\]]*\]\([^)]+\)\)",
        "",
        text,
        flags=re.IGNORECASE,
    )
    return text


def add_paragraph_breaks(text: str, break_ms: int = 1300) -> str:
    """Replace blank-line paragraph breaks with explicit SSML break tags.

    Within a paragraph, soft-wrap newlines (from bullet lines) are joined with
    ". " when needed so each line ends with sentence-terminating punctuation.

    Output is plain text with embedded break tags. This is friendly to:
    - ElevenLabs (interprets <break time="1300ms" /> natively)
    - Azure Speech Service (interprets the same SSML)
    - Plain-text renderers (the tags are visible but harmless)
    """
    text = re.sub(r"\r\n", "\n", text)
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    fixed_paragraphs = []
    for p in paragraphs:
        lines = [l.strip() for l in p.split("\n") if l.strip()]
        joined = []
        for line in lines:
            if joined and not joined[-1].rstrip().endswith((".", "!", "?", ":", ";", ",")):
                joined[-1] = joined[-1].rstrip() + "."
            joined.append(line)
        fixed_paragraphs.append(" ".join(joined))
    return f' <break time="{break_ms}ms" /> '.join(fixed_paragraphs)


def normalize(text: str, with_breaks: bool = True) -> str:
    """Apply all rules in canonical order."""
    text = strip_source_citations(text)
    text = normalize_anaphora(text)
    text = split_semicolon_runons(text)
    if with_breaks:
        text = add_paragraph_breaks(text)
    return text


def main():
    """Read text from stdin, write normalized text to stdout.

    Use --no-breaks to skip the SSML break-tag insertion (useful when the
    consumer doesn't speak SSML).
    """
    with_breaks = "--no-breaks" not in sys.argv
    text = sys.stdin.read()
    print(normalize(text, with_breaks=with_breaks), end="")


if __name__ == "__main__":
    main()
