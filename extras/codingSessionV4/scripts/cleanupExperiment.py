"""Remove only verified V4 source/runtime scratch after publication audit passes."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from typing import TypedDict

root = Path('/tmp/codingSessionV4')
owned = Path('/home/leon/.cache/codingSessionV4Owned')
publication = Path(__file__).resolve().parents[1]


class Untracked(TypedDict):
    bytes: int
    sha256: str


class Original(TypedDict):
    head: str
    trackedStatus: str
    editedHashes: dict[str, str]
    untracked: dict[str, Untracked]


class Removal(TypedDict):
    path: str
    reason: str


class Inventory(TypedDict):
    excluded: list[Removal]


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True)


def digest(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def checkOriginals() -> dict[str, list[str]]:
    originals: dict[str, Original] = json.loads((root / 'originalProjects.json').read_text())
    changes: dict[str, list[str]] = {}
    for name, entry in originals.items():
        repo = Path(name)
        differences: list[str] = []
        if git(repo, 'rev-parse', 'HEAD').strip() != entry['head']:
            differences.append('HEAD changed')
        if git(repo, 'status', '--porcelain=v1', '-uno') != entry['trackedStatus']:
            differences.append('tracked status changed')
        for path, expected in entry['editedHashes'].items():
            if not (repo / path).is_file() or digest(repo / path) != expected:
                differences.append('pre-existing tracked edit changed: ' + path)
        for path, expected in entry['untracked'].items():
            source = repo / path
            if not source.is_file() or source.stat().st_size != expected['bytes']:
                differences.append('pre-existing untracked file missing/size changed: ' + path)
            elif len(expected['sha256']) == 64 and digest(source) != expected['sha256']:
                differences.append('pre-existing untracked file changed: ' + path)
        changes[name] = differences
    return changes


def remove(path: Path, reason: str, records: list[Removal]) -> None:
    if not path.exists() and not path.is_symlink():
        return
    allowed = (root, owned)
    if not any(path.is_relative_to(prefix) for prefix in allowed):
        raise ValueError('Not an owned experiment path: ' + str(path))
    if path.is_symlink():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()
    records.append({'path': str(path), 'reason': reason})


def removeWorktrees(records: list[Removal]) -> None:
    repositories = [Path.home() / 'workspace/projects' / name for name in ['atlas', 'matato', 'dotfiles']]
    for repo in repositories:
        paths = [Path(line.removeprefix('worktree ')) for line in git(repo, 'worktree', 'list', '--porcelain').splitlines()
                 if line.startswith('worktree ')]
        for path in paths:
            if not any(path.is_relative_to(prefix) for prefix in (root, owned)):
                continue
            subprocess.run(['git', '-C', str(repo), 'worktree', 'remove', '--force', str(path)], check=True)
            records.append({'path': str(path), 'reason': 'owned registered experiment worktree'})


def removeLegacyClones(records: list[Removal]) -> None:
    for name in ['ponytail-skill-review', 'ponytail-explain']:
        path = Path('/tmp') / name
        if not (path / '.git').is_dir():
            continue
        remote = git(path, 'remote', 'get-url', 'origin').strip().removesuffix('.git')
        if remote != 'https://github.com/DietrichGebert/ponytail' or git(path, 'status', '--porcelain=v1', '--untracked-files=all'):
            raise ValueError('Legacy clone has unexpected ownership/edits; preserved: ' + str(path))
        shutil.rmtree(path)
        records.append({'path': str(path), 'reason': 'verified pristine legacy temporary Ponytail upstream clone'})


def removeReviewerScratch(records: list[Removal]) -> None:
    paths = [Path('/dev/shm') / name for name in ['codingSessionV4tuningReview',
             'codingSessionV4tuningTwoReview', 'codingSessionV4tuningTwoSynthetic']]
    paths.append(Path.home() / '.cache/codingSessionV4Review')
    for path in paths:
        if path.is_dir():
            shutil.rmtree(path)
            records.append({'path': str(path), 'reason': 'V4 reviewer disposable copies/synthetic storage probes; logs archived'})


def removeSyntheticScratch(records: list[Removal]) -> None:
    remove(root / 'selfChecks', 'synthetic harness source/config fixtures; proof metadata archived', records)
    remove(root / '__pycache__', 'experiment Python bytecode cache', records)
    for path in (owned / 'publicationPrep').glob('publicationSelfCheck*'):
        remove(path, 'synthetic archive fixtures; self-check proof archived', records)


def main() -> None:
    subprocess.run(['python', str(owned / 'publicationPrep/packageEvidence.py'), 'verify'], check=True)
    if not (publication / 'archiveAudit.json').is_file():
        raise ValueError('Independent archive audit record required before cleanup')
    before = checkOriginals()
    records: list[Removal] = []
    removeWorktrees(records)
    inventory: Inventory = json.loads((owned / 'publicationPrep/auditInventory.json').read_text())
    for entry in inventory['excluded']:
        if entry['reason'] in ['source/dependency/private/runtime tree', 'private/upstream/source/cache tree']:
            path = root / entry['path']
            if any(path.is_relative_to(root / area) for area in ['research', 'evidence', 'reviews', 'worktrees']):
                remove(path, 'archived logs retained; excluded owned source/runtime copy', records)
    for path in root.glob('runs/*/ponytail/*/currentProfile.md'):
        remove(path, 'excluded Ponytail profile; pin and whole implementation evidence retained', records)
    remove(root / 'profiles/ponytail.md', 'temporary Ponytail comparison profile', records)
    remove(root / 'ponytail', 'temporary pinned Ponytail upstream checkout', records)
    remove(owned / 'private', 'private auth copies/raw streams/runtime; never published', records)
    remove(root / 'private', 'logical private storage link', records)
    remove(owned / 'worktrees', 'remaining owned source directories after Git deregistration', records)
    remove(root / 'worktrees', 'logical owned worktree directories/links', records)
    removeLegacyClones(records)
    removeReviewerScratch(records)
    removeSyntheticScratch(records)
    after = checkOriginals()
    output = {'archiveVerifiedBeforeCleanup': True, 'removals': records,
              'originalProjectDifferencesBefore': before, 'originalProjectDifferencesAfter': after,
              'historicalEvidenceTouched': False, 'readmeChanged': False,
              'remainingPonytailProfileCopies': [str(path) for path in root.glob('runs/*/ponytail/*/currentProfile.md')],
              'limits': 'Pre-existing large untracked files were size-checked, not hashed; unrelated pre-existing Ponytail test fixture directories are not V4 installs. No original source/reset/clean command used.'}
    (publication / 'cleanup.json').write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps({'removals': len(records), 'originalDifferences': {k: v for k, v in after.items() if v}}))


if __name__ == '__main__':
    main()
