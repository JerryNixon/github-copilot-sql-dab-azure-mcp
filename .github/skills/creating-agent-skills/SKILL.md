---
name: creating-agent-skills
description: Guide for creating GitHub Copilot Agent Skills. Use this when asked to create new skills, understand skill structure, or improve existing skills.
license: MIT
---

# Creating GitHub Copilot Agent Skills

This skill teaches agents how to create well-structured, effective Agent Skills for GitHub Copilot. Agent Skills are folders of instructions, scripts, and resources that Copilot loads when relevant to improve performance in specialized tasks.

---

## When to Create a Skill

### Create a Skill When:
- Task requires **detailed, repeatable instructions** for a specific workflow
- Process has multiple steps that need consistent execution
- Instructions are **contextually loaded** (not needed for every task)
- You're documenting complex tool usage (CLI, API, framework)
- Multiple users/projects would benefit from standardized guidance

### Use Custom Instructions Instead When:
- Instructions apply to **almost every task** in the repository
- Guidance is about coding standards, style preferences, or conventions
- Instructions are simple and brief (1-2 sentences)

**Rule of Thumb:** Custom instructions are like `.editorconfig`, skills are like documentation.

---

## Skill Structure Requirements

### Directory Structure

**Project Skills** (repository-specific):
```
.github/skills/<skill-name>/
├── SKILL.md          (required)
├── scripts/          (optional)
├── examples/         (optional)
└── resources/        (optional)
```

**Alternative:** `.claude/skills/<skill-name>/` is also supported for compatibility.

**Personal Skills** (user-wide):
```
~/.copilot/skills/<skill-name>/
├── SKILL.md
└── ...
```

**Alternative:** `~/.claude/skills/<skill-name>/` is also supported.

### Naming Rules

**Directory name:**
- Lowercase only
- Use hyphens for spaces
- Match the `name` in frontmatter
- Examples: `github-actions-debugging`, `api-testing`, `database-migrations`

**File name:**
- MUST be `SKILL.md` (case-sensitive, all caps)
- No other name will be recognized

---

## SKILL.md File Format

### Required YAML Frontmatter

Every `SKILL.md` MUST start with YAML frontmatter containing:

```yaml
---
name: skill-name-here
description: Brief description of what this skill does and when to use it.
---
```

**Frontmatter Requirements:**

| Field | Required | Format | Purpose |
|-------|----------|--------|---------|
| `name` | **Yes** | Lowercase with hyphens | Unique identifier matching directory name |
| `description` | **Yes** | Plain text (50-150 chars) | Tells Copilot when to use this skill |
| `license` | No | Text or SPDX identifier | License terms for the skill |

**Critical:** The frontmatter MUST be the very first thing in the file. No blank lines before the opening `---`.

### Prelude Requirement

The skill content should immediately follow the frontmatter and start with a clear statement of purpose. This "prelude" helps both humans and AI understand the skill's scope.

**Pattern:**
```markdown
---
name: your-skill
description: One-line description
---

# Skill Title

Brief introduction explaining what this skill does, what it helps with, and its primary use cases.

---

[Rest of skill content]
```

---

## Writing Effective Skill Descriptions

The `description` field determines **when Copilot loads your skill**. Make it specific and action-oriented.

### Good Descriptions ✅

```yaml
description: Guide for debugging failing GitHub Actions workflows. Use this when asked to debug failing GitHub Actions workflows.
```
```yaml
description: Instructions for creating and managing DAB configurations. Use when working with Data API Builder CLI, entities, or database API generation.
```
```yaml
description: PostgreSQL query optimization techniques. Use when debugging slow queries or improving database performance.
```

### Bad Descriptions ❌

```yaml
description: GitHub Actions stuff
# Too vague - when should this be used?
```
```yaml
description: This skill contains comprehensive information about Docker containerization, Kubernetes orchestration, CI/CD pipelines, monitoring, and cloud deployment strategies.
# Too broad - should be multiple skills
```
```yaml
description: Helper for things
# Not actionable - what things?
```

### Description Best Practices

1. **Be specific**: Mention the tool, framework, or task type
2. **Include trigger phrases**: "Use this when asked to...", "Use when working with..."
3. **Keep it concise**: 50-150 characters ideal
4. **Use action verbs**: debugging, creating, optimizing, configuring
5. **Avoid jargon alone**: Include context (not just "DAB" but "Data API Builder")

---

## Skill Content Structure

### Recommended Sections

```markdown
# Skill Title

Brief introduction (2-3 sentences)

---

## Core Concepts / Mental Model

Foundational understanding needed to use the skill effectively

## Common Workflows / Decision Trees

Step-by-step processes for typical tasks

## Command Reference / API Guide

Detailed reference for tools, commands, or APIs

## Examples / Templates

Concrete examples users can adapt

## Troubleshooting / FAQ

Common problems and solutions

## References

Links to official documentation
```

### Writing Style Guidelines

**Do:**
- Use clear, imperative language ("Run this command", "Check for...")
- Provide code examples in fenced code blocks with language hints
- Structure with headings, lists, and tables for scannability
- Include both "happy path" and edge cases
- Offer decision trees for complex scenarios ("If X, then do Y")
- Use consistent terminology throughout

**Don't:**
- Write long paragraphs - prefer bullet points
- Assume prior knowledge - explain acronyms on first use
- Duplicate official docs - link to them and add value
- Use "you might want to" - be directive ("Do X to achieve Y")
- Mix different tools or concepts - keep skills focused

---

## Code Examples Best Practices

### Format Code Blocks

Always specify the language for syntax highlighting:

````markdown
```bash
git --no-pager log --oneline -n 10
```

```yaml
name: my-skill
description: Example skill
```

```json
{
  "entities": {
    "Product": {
      "source": "dbo.Products"
    }
  }
}
```
````

### Provide Context

Don't just show code - explain when and why:

```markdown
## Checking Workflow Status

To see recent workflow runs in a pull request:

```bash
gh run list --repo owner/repo --limit 10
```

This shows the 10 most recent runs with their status and conclusion.
```

### Use Annotations

Help users understand what to customize:

```bash
dab add <entity-name> \
  --source <schema.table> \
  --permissions "anonymous:read"
```

Or with comments:

```bash
# Replace with your database type: mssql, postgresql, mysql
dab init --database-type mssql \
  --connection-string "@env('CONNECTION_STRING')"
```

---

## Decision Trees & Conversational Patterns

Skills work best when they guide agents through decision-making.

### Pattern: User Intent Detection

```markdown
### User says: "add entity" or "add table"

**Ask:**
1. Entity name? (logical API name)
2. Source object? (include schema, e.g., `dbo.Products`)
3. Source type? (`table`, `view`, `stored-procedure`)
4. Permissions? (at least one `role:actions` pair)

**Then offer:**
```bash
dab add Product \
  --source dbo.Products \
  --permissions "anonymous:read"
```
```

### Pattern: Troubleshooting Flow

```markdown
### Problem: "Validation failed"

**Troubleshoot in order:**
1. Check config file exists and is valid JSON
2. Verify environment variables are set
3. Test database connectivity
4. Validate entity names match database objects
5. Review error output for specific stage failure

**If stage is "permissions":**
- Check role names match auth provider
- Verify action names are valid (`create`, `read`, `update`, `delete`, `*`)
```

---

## Including Scripts and Resources

Skills can include supporting files:

```
.github/skills/database-backup/
├── SKILL.md
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   └── verify-backup.sh
├── examples/
│   └── cron-schedule.txt
└── README.md
```

Reference them in your SKILL.md:

```markdown
## Running Backups

Use the included backup script:

```bash
./scripts/backup.sh --database mydb --output /backups
```

See `examples/cron-schedule.txt` for automated scheduling.
```

---

## Skill Activation & Context

### How Copilot Uses Skills

1. User sends a prompt to Copilot
2. Copilot reads all skill `description` fields
3. Copilot decides which skills are relevant based on:
   - Keywords in the prompt
   - Current task context
   - Trigger phrases in descriptions
4. Copilot loads the full `SKILL.md` content into context
5. Copilot follows the skill's instructions to complete the task

### What Gets Loaded

When a skill is activated:
- The entire `SKILL.md` file content
- Any files referenced in the skill directory (if agent requests them)

**Important:** Skills consume context window tokens. Keep them focused and concise.

---

## Testing Your Skill

### Validation Checklist

Before committing a skill:

- [ ] Directory name is lowercase with hyphens
- [ ] Directory name matches `name` in frontmatter
- [ ] File is named exactly `SKILL.md` (case-sensitive)
- [ ] YAML frontmatter is first thing in file (no blank lines above)
- [ ] `name` field is lowercase with hyphens
- [ ] `description` field clearly states when to use the skill
- [ ] Content starts with a clear introduction/prelude
- [ ] Code blocks specify language for syntax highlighting
- [ ] Examples are complete and runnable
- [ ] Instructions are clear and actionable
- [ ] No sensitive data (passwords, API keys, tokens)

### Manual Testing

1. Create a test prompt that should trigger your skill
2. Ask Copilot to perform the task
3. Observe if Copilot uses the skill's guidance
4. Verify the output follows your instructions
5. Iterate on description and content as needed

### Example Test Prompts

For a skill named `github-actions-debugging`:
- "Debug the failing CI workflow in this PR"
- "Why is my GitHub Actions build failing?"
- "Help me understand this workflow error"

For a skill named `api-testing`:
- "Create tests for the REST API endpoints"
- "How do I test the authentication flow?"

---

## Common Skill Patterns

### CLI Tool Skill

```markdown
---
name: tool-name-cli
description: Guide for using ToolName CLI. Use when working with tool-name commands, configuration, or workflows.
---

# ToolName CLI Guide

## Installation

## Core Commands

### command-name
**Purpose:** What it does

**Syntax:**
```bash
tool command [options]
```

**Options:** (table of options)

**Examples:**

### command-name-2
...

## Common Workflows

## Troubleshooting
```

### Framework Skill

```markdown
---
name: framework-patterns
description: Best practices for FrameworkName. Use when building, testing, or debugging FrameworkName applications.
---

# FrameworkName Patterns

## Core Concepts

## Project Structure

## Common Tasks

### Creating Components

### Managing State

### Testing

## Anti-Patterns to Avoid

## Performance Optimization
```

### Workflow/Process Skill

```markdown
---
name: process-name
description: Guide for ProcessName workflow. Use when asked to perform ProcessName tasks.
---

# ProcessName Workflow

## When to Use This Process

## Prerequisites

## Step-by-Step Guide

1. **Step 1:** Do this
   ```bash
   command here
   ```
   
2. **Step 2:** Then this

## Validation

## Rollback Procedure
```

---

## Multi-Skill Coordination

When you have related skills, reference them:

```markdown
## Related Skills

- See `database-migrations` skill for schema change workflows
- See `api-testing` skill for endpoint validation
- Refer to custom instructions in `.github/copilot-instructions.md` for coding standards
```

---

## Maintenance & Updates

### When to Update a Skill

- Tool/framework version changes
- New best practices emerge
- User feedback reveals gaps
- Common errors not covered

### Version Notes Section

For tools with version-specific features:

```markdown
## Version-Specific Features

### v2.0+ Only
- New feature X
- Changed behavior Y

### Legacy (v1.x)
- Old approach (now deprecated)
```

---

## Security Considerations

**Never include in skills:**
- Passwords or API keys
- Connection strings with credentials
- Private repository URLs
- Personally identifiable information (PII)
- Proprietary code or algorithms

**Instead:**
- Use `@env('VARIABLE_NAME')` pattern for secrets
- Reference credential management systems
- Link to secure documentation
- Provide templates with placeholders

---

## Example: Complete Minimal Skill

```markdown
---
name: postgres-backup
description: Guide for PostgreSQL backup and restore operations. Use when backing up or restoring PostgreSQL databases.
---

# PostgreSQL Backup & Restore

This skill provides commands and workflows for safely backing up and restoring PostgreSQL databases.

---

## Backup Commands

### Full Database Backup

```bash
pg_dump -h localhost -U username -d database_name -F c -f backup_file.dump
```

Options:
- `-F c`: Custom format (compressed, recommended)
- `-F p`: Plain SQL format (human-readable)

### Schema-Only Backup

```bash
pg_dump -h localhost -U username -d database_name --schema-only -f schema.sql
```

## Restore Commands

### From Custom Format

```bash
pg_restore -h localhost -U username -d database_name -F c backup_file.dump
```

### From SQL File

```bash
psql -h localhost -U username -d database_name -f backup_file.sql
```

## Automated Backups

Create a cron job:

```bash
# Daily backup at 2 AM
0 2 * * * /usr/bin/pg_dump -h localhost -U postgres -d mydb -F c -f /backups/mydb_$(date +\%Y\%m\%d).dump
```

## Troubleshooting

### "Permission denied"
- Verify PostgreSQL user has sufficient privileges
- Check file system permissions on backup directory

### "Database does not exist"
- Create target database before restoring: `createdb database_name`

## References

- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
```

---

## Quick Reference: Skill Creation Checklist

When creating a new skill:

1. **Plan**
   - [ ] Identify specific task/tool the skill covers
   - [ ] Verify it's not better as a custom instruction
   - [ ] Choose clear, descriptive name (lowercase-with-hyphens)

2. **Structure**
   - [ ] Create directory: `.github/skills/<skill-name>/`
   - [ ] Create file: `SKILL.md` (exactly this name)

3. **Frontmatter**
   - [ ] Add YAML frontmatter (no blank lines before `---`)
   - [ ] Set `name` (lowercase, hyphens, matches directory)
   - [ ] Set `description` (when to use, 50-150 chars)
   - [ ] Add `license` if applicable

4. **Content**
   - [ ] Start with clear introduction/prelude
   - [ ] Structure with clear headings
   - [ ] Provide actionable instructions
   - [ ] Include code examples with language hints
   - [ ] Add decision trees for complex workflows
   - [ ] Include troubleshooting section
   - [ ] Link to official documentation

5. **Quality**
   - [ ] No sensitive data (secrets, credentials)
   - [ ] Examples are complete and runnable
   - [ ] Instructions are clear and specific
   - [ ] No spelling/grammar errors
   - [ ] Consistent terminology

6. **Test**
   - [ ] Create test prompts that should trigger the skill
   - [ ] Verify Copilot uses the skill appropriately
   - [ ] Check that instructions produce correct results

---

## References

- [GitHub Copilot Agent Skills Documentation](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)
- [Agent Skills Open Standard](https://github.com/agentskills/agentskills)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)
- [Awesome Copilot Collection](https://github.com/github/awesome-copilot)
