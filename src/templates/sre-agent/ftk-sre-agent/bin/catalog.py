"""Convert canonical FinOps catalog queries to SRE Agent tools."""

import re


def read_query(path):
    lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
    start = next((index for index, line in enumerate(lines)
                  if line.strip() and not line.strip().startswith('//')), 0)
    return '\n'.join(lines[start:]).rstrip()


def read_header(path):
    comments = []
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        line = line.strip()
        if not line:
            continue
        if not line.startswith('//'):
            break
        comments.append(line[2:].strip())
    return comments


def description(path, comments):
    title = path.stem.replace('-', ' ')
    lines = []
    started = False
    for comment in comments:
        if comment == 'Description:':
            started = True
            continue
        if comment == 'Parameters:' or comment.startswith('Query:'):
            if started:
                break
            if comment.startswith('Query:'):
                title = comment.split(':', 1)[1].strip() or title
            continue
        if started and comment:
            lines.append(comment)
    return ' '.join(lines) or f'Runs the {title} FinOps Hub catalog query.'


def parameters(comments, query):
    result = []
    seen = set()
    started = False
    for comment in comments:
        if comment == 'Parameters:':
            started = True
            continue
        if not started:
            continue
        if comment.startswith(('Each row', 'Use this query')) or comment.lower().startswith('none'):
            break
        name, separator, detail = comment.partition(':')
        name = name.strip()
        if not separator or name in seen or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name):
            continue
        if not re.search(rf'^let\s+{re.escape(name)}\s*=', query, flags=re.MULTILINE):
            continue
        seen.add(name)
        result.append({'name': name, 'type': 'string', 'description': detail.strip(), 'required': True})
    return result


def build_tools(directory):
    tools = []
    for path in sorted(directory.glob('*.kql')):
        query = read_query(path)
        comments = read_header(path)
        specs = parameters(comments, query)
        for param in specs:
            name = param['name']
            query = re.sub(rf'^let\s+{re.escape(name)}\s*=\s*[^;\n]+;', f'let {name} = ##{name}##;',
                           query, count=1, flags=re.MULTILINE)
        definition = {
            'type': 'KustoTool', 'connector': 'finops-hub-kusto', 'database': 'Hub', 'toolMode': 'Auto',
            'description': description(path, comments), 'query': query,
        }
        if specs:
            definition['parameters'] = specs
        tools.append({'metadata': {'name': path.stem}, 'spec': definition})
    if not tools:
        raise ValueError(f'FinOps query catalog is empty or missing: {directory}')
    return tools
