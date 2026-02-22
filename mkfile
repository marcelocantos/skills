skills_src = $[shell echo ~/.claude/skills]
skill_dirs = $[shell find $skills_src -mindepth 1 -maxdepth 1 -type d ! -name '.*' -exec basename {} \;]
skill_files = $[shell find $skills_src -mindepth 2 -name '*.md' | sed "s|$skills_src/||"]

!publish:
    @echo "Syncing skills from $skills_src..."
    for dir in $skill_dirs; do
        mkdir -p "$$dir"
    done
    for f in $skill_files; do
        cp "$skills_src/$$f" "$$f"
    done
    @echo "Updating README.md..."
    python3 <<'PYEOF'
    import os, re
    skills = []
    for d in sorted(os.listdir('.')):
        p = os.path.join(d, 'SKILL.md')
        if not os.path.isfile(p):
            continue
        with open(p) as f:
            text = f.read()
        m = re.search(r'^description:\s*(.+)$', text, re.MULTILINE)
        desc = m.group(1).strip() if m else ''
        skills.append((d, desc))
    lines = [
        '# Skills',
        '',
        'Claude Code skills for use with `~/.claude/skills/`.',
        '',
        '## Available Skills',
        '',
    ]
    for name, desc in skills:
        lines.append(f'- **[`/{name}`]({name}/SKILL.md)** — {desc}')
    lines += ['', '## License', '', 'Apache-2.0', '']
    with open('README.md', 'w') as f:
        f.write('\n'.join(lines))
    PYEOF
    if git diff --quiet README.md $skill_files 2>/dev/null && [ -z "$$(git ls-files --others --exclude-standard -- $skill_files)" ]; then
        echo "No changes to publish."
    else
        git add README.md $skill_files
        git diff --cached --stat
        git commit -m "Update skills from ~/.claude/skills"
        git push
        echo "Published."
    fi
