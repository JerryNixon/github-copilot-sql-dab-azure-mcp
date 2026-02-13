---
name: creating-agent-skills
description: Guide for creating and auditing Agent Skills. Use when asked to create a new skill, review an existing SKILL.md, or improve skill metadata and structure.
---

# Creating Agent Skills

Create and audit skills that are concise, trigger correctly, and follow current Agent Skills + VS Code conventions.

## Canonical references

- https://code.visualstudio.com/docs/copilot/customization/agent-skills
- https://github.com/microsoft/skills
- https://agentskills.io/specification

## Required documentation links at top

Every skill/agent instruction file must include a short **Documentation references** section near the top of the file (immediately after title/intro), with raw source URLs.

Rules:

- Use plain raw URLs (for example: `https://...`) to authoritative docs.
- Include at least 2 links when available: product docs + official/reference repo.
- Keep this section concise (just the links, optional one-line label).
- Prefer stable official pages over blogs/community posts.

## When to use this skill

Use this skill when the request is about:

- creating a new skill directory with `SKILL.md`
- auditing/fixing an existing `SKILL.md`
- improving frontmatter for better auto-activation
- splitting bloated skill content into `references/` files

Use repo custom instructions instead when guidance is always-on coding policy/style.

## Required `SKILL.md` frontmatter

Include YAML frontmatter at the top of the file (no content before `---`):

- `name` (required)
  - 1-64 chars
  - lowercase letters/numbers/hyphens only
  - cannot start/end with `-`
  - cannot contain `--`
  - must match the skill directory name
- `description` (required)
  - 1-1024 chars
  - must describe **what** the skill does and **when** to use it
  - include concrete task keywords to improve relevance matching

## Optional frontmatter

Use only when needed:

- Spec-level: `license`, `compatibility`, `metadata`, `allowed-tools` (experimental)
- VS Code-specific: `argument-hint`, `user-invokable`, `disable-model-invocation`

Do not add optional fields by default.

## Recommended directory structure

Use the minimal structure first:

- `SKILL.md` (required)
- `scripts/` (optional executable helpers)
- `references/` (optional detailed docs loaded on demand)
- `assets/` (optional templates/static resources)

Prefer progressive disclosure:

1. Keep frontmatter precise (discovery)
2. Keep `SKILL.md` body focused (activation)
3. Move detail to `references/` (on-demand)

Target: keep `SKILL.md` compact (generally under ~500 lines).

## Authoring rules for lean skills

- Be specific, not broad.
- Keep instructions task-oriented and actionable.
- Avoid duplicating large official docs; link to them.
- Avoid meta docs in skill folders (`README.md`, changelog files) unless explicitly required.
- Never include secrets or hardcoded credentials.

## Audit checklist

When auditing an existing skill, check and fix in this order:

1. Frontmatter validity (`name`, `description`, top-of-file YAML)
2. Trigger quality in `description` (what + when)
3. Concision (remove irrelevant/tutorial bloat)
4. Structure (`scripts/`, `references/`, `assets` usage)
5. Top-of-file documentation links exist and point to raw official docs
6. Broken or stale guidance vs current docs
7. Security issues (secrets, unsafe defaults)

## Minimal skill template

```markdown
---
name: your-skill-name
description: What this skill does and when to use it.
---

# Skill Title

Short purpose statement.

## Documentation references

- https://official-docs.example.com
- https://official-reference-repo.example.com

## Workflow

1. Step one
2. Step two
3. Step three

## References

- [Official docs](https://example.com)
- Detailed guide in `references/` (optional)
```

## Notes for maintainers

If guidance conflicts with docs, prefer:

1. Agent Skills specification (`agentskills.io/specification`)
2. VS Code Agent Skills docs
3. patterns used in `microsoft/skills`
