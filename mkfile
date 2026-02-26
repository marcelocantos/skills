skills_src = $[shell echo ~/.claude/skills]

!publish:
    @echo "Syncing skills from $skills_src..."
    rsync -a --exclude='.*' --delete --filter='P README.md' --filter='P .git/' --filter='P mkfile' --filter='P LICENSE' $skills_src/ .
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
    git add -A
    if git diff --cached --quiet; then
        echo "No changes to publish."
    else
        git diff --cached --stat
        git commit -m "Update skills from ~/.claude/skills"
        git push
        echo "Published."
    fi
