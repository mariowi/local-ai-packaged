# Contributing to CAAL

Thank you for your interest in contributing to CAAL! This guide covers all components: the Python voice agent, Next.js frontend, and Flutter mobile app.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Standards](#code-standards)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/CAAL.git
   cd CAAL
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/CoreWorxLab/CAAL.git
   ```

## Development Setup

### Python Agent (voice_agent.py, src/caal/)

**Prerequisites:**
- Python 3.10+
- [uv](https://github.com/astral-sh/uv) package manager
- Docker (for infrastructure services)

**Setup:**
```bash
# Install dependencies
uv sync

# Start infrastructure (LiveKit, Speaches, Kokoro)
docker compose up -d livekit speaches kokoro

# Run agent locally
uv run voice_agent.py dev
```

**Linting & Testing:**
```bash
uv run ruff check src/       # Lint
uv run ruff check src/ --fix # Auto-fix
uv run mypy src/             # Type check
uv run pytest                # Run tests
```

### Frontend (frontend/)

**Prerequisites:**
- Node.js 18+
- pnpm

**Setup:**
```bash
cd frontend
cp .env.example .env.local
pnpm install
pnpm dev
```

**Linting & Formatting:**
```bash
pnpm lint          # ESLint
pnpm format        # Prettier format
pnpm format:check  # Check formatting
```

### Mobile App (mobile/)

**Prerequisites:**
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.5.1+
- Android Studio or Xcode

**Setup:**
```bash
cd mobile
flutter pub get
flutter run
```

## Code Standards

### Python
- Follow [PEP 8](https://pep8.org/) style guide
- Use type hints for function signatures
- Line length: 100 characters (configured in pyproject.toml)
- Linter: ruff
- Type checker: mypy

### TypeScript/JavaScript (Frontend)
- Use TypeScript for all new code
- Follow ESLint configuration
- Format with Prettier
- Use functional components with hooks

### Dart (Mobile)
- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use Flutter best practices

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

**Scopes:** `agent`, `frontend`, `mobile`, `docs`, `ci`

**Examples:**
```
feat(agent): add support for custom wake word models
fix(frontend): resolve dark mode toggle persistence
docs: update deployment instructions for Tailscale
```

## Pull Request Process

1. **Create a branch:**
   ```bash
   git checkout -b feat/your-feature-name
   # or: fix/bug-description, docs/what-changed
   ```

2. **Make changes** following code standards

3. **Keep branch updated:**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

4. **Push and create PR:**
   ```bash
   git push origin feat/your-feature-name
   ```

5. **PR Requirements:**
   - Clear description of changes
   - Link related issues
   - All CI checks passing
   - Screenshots for UI changes
   - Documentation updated if needed

## Reporting Issues

### Bug Reports
Include:
- Clear description
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, deployment mode, versions)
- Relevant logs

### Feature Requests
Include:
- Problem you're solving
- Proposed solution
- Use case and who benefits

## Questions?

- Open a [Discussion](https://github.com/CoreWorxLab/CAAL/discussions)
- Check existing issues and docs

Thank you for contributing!
