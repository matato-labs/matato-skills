"""Summarize V4 frozen records; do not turn partial outputs into successful draws."""
import hashlib
import json
from pathlib import Path
from typing import NotRequired, TypedDict

root = Path('/tmp/codingSessionV4')
destination = Path(__file__).resolve().parents[1] / 'results.json'


class FileMetric(TypedDict):
    path: str
    category: str
    added: int
    deleted: int
    churn: int
    baseBytes: int
    resultBytes: int
    byteGrowth: int
    normalizedAdded: int
    normalizedDeleted: int


class Trial(TypedDict):
    status: str
    agentExit: int | None
    acceptanceExit: int | None
    nativeExit: int | None
    profileSha256: str
    files: NotRequired[list[FileMetric]]


class Metric(TypedDict):
    added: int
    deleted: int
    churn: int
    baseBytes: int
    resultBytes: int
    byteGrowth: int
    normalizedAdded: int
    normalizedDeleted: int


class Row(TypedDict):
    draw: str
    arm: str
    case: str
    status: str
    agentExit: int | None
    acceptanceExit: int | None
    nativeExit: int | None
    profileSha256: str | None
    categories: dict[str, Metric]
    qualification: str


def emptyMetric() -> Metric:
    return {'added': 0, 'deleted': 0, 'churn': 0, 'baseBytes': 0, 'resultBytes': 0,
            'byteGrowth': 0, 'normalizedAdded': 0, 'normalizedDeleted': 0}


def readRow(draw: str, arm: str, case: str) -> Row:
    path = root / 'runs' / draw / arm / case / 'result.json'
    row: Row = {'draw': draw, 'arm': arm, 'case': case, 'status': 'unavailable',
                'agentExit': None, 'acceptanceExit': None, 'nativeExit': None,
                'profileSha256': None, 'categories': {},
                'qualification': 'Frozen execution only; independent quality findings remain separate.'}
    try:
        trial: Trial = json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        row['qualification'] = 'Original missing/truncated record; see failed-round review, not zero output.'
        return row
    row.update(status=trial['status'], agentExit=trial['agentExit'],
               acceptanceExit=trial['acceptanceExit'], nativeExit=trial['nativeExit'],
               profileSha256=trial['profileSha256'])
    for item in trial.get('files', []):
        category = 'production' if item['path'] == 'setup' else item['category']
        total = row['categories'].setdefault(category, emptyMetric())
        total['added'] += item['added']
        total['deleted'] += item['deleted']
        total['churn'] += item['churn']
        total['baseBytes'] += item['baseBytes']
        total['resultBytes'] += item['resultBytes']
        total['byteGrowth'] += item['byteGrowth']
        total['normalizedAdded'] += item['normalizedAdded']
        total['normalizedDeleted'] += item['normalizedDeleted']
    return row


def main() -> None:
    tuning = ['pythonConfinedIgnoreFiles', 'preScriptEnvironmentLifetime']
    complete = tuning + ['sequenceCreateRecovery', 'shellBootstrapLocation']
    rows: list[Row] = []
    for draw in ['ablationOne', 'tuningOne', 'tuningTwo', 'finalOne', 'finalTwo']:
        candidate = 'candidateOne' if draw == 'tuningOne' else 'candidateTwo'
        arms = ['v3', 'reuseAblation'] if draw == 'ablationOne' else ['v3', 'v2', 'ponytail', candidate]
        rows.extend(readRow(draw, arm, case) for arm in arms
                    for case in (complete if draw.startswith('final') else tuning))
    reports = {phase: hashlib.sha256((root / 'reviews' / phase / 'review.md').read_bytes()).hexdigest()
               for phase in ['ablationOne', 'tuningOne', 'tuningTwo', 'finalOne', 'finalTwo']}
    header = {'verdict': 'NOT MET: production threshold and quality/completion gates not established',
              'requestedIdentities': len(rows), 'reservations': 51, 'actualImplementationProcesses': 50,
              'candidateBytes': 2630, 'candidateSha256': '6efa072c53b7e83aae7a17f4f60a45efd113cd8dc927c1c1ebf815ec3cd25643',
              'runtimeCeilingBytes': 2642, 'independentReviewHashes': reports,
              'accounting': 'setup is production, correcting frozen suffix categorization equally. Result bytes cover changed files, not whole repositories. No partial cross-arm pooled success score. Independent per-case/matched-inventory metrics and all supplements are archived.',
              'mutation': 'No installed Atlas mutation support; zero mutants, not a pass.'}
    lines = ['{', *[f'  {json.dumps(key)}: {json.dumps(value)},' for key, value in header.items()],
             '  "implementations": [', *['    ' + json.dumps(row) + (',' if index < len(rows) - 1 else '')
                                         for index, row in enumerate(rows)], '  ]', '}']
    destination.write_text('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
