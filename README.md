# realias

[![npm version](https://img.shields.io/npm/v/realias.svg)](https://www.npmjs.com/package/realias)
[![npm downloads](https://img.shields.io/npm/dm/realias.svg)](https://www.npmjs.com/package/realias)
[![license](https://img.shields.io/npm/l/realias.svg)](https://github.com/Maverik2912/realias/blob/main/LICENSE)

Rewrite relative imports in TypeScript/JavaScript projects to the most specific
path alias from your `tsconfig.json` — and re-alias existing aliased imports
when a better match is added. Lightweight CLI: pure bash + perl, no Node.js
runtime required.

## Why

You add `@components/*` to `tsconfig.json#compilerOptions.paths`, but your
codebase is still full of `../../../components/Button`. Or you add a more
specific `@v2/*` alias and want existing `@components/v2/...` imports to use
it. `realias` walks the project, resolves each import to an absolute path, and
rewrites it to the shortest/most-specific alias available.

## Install

```bash
# global — installs the `realias` command on your $PATH
npm install -g realias

# project — runnable via npx / npm scripts
npm install -D realias
```

> **Requirements**: `bash`, `perl`, `find`, `awk`, `sed`. All preinstalled on
> macOS and every mainstream Linux distro. No Node.js runtime needed at
> execution time — Node is only used by npm for installation.

## Quick start

From any directory inside your project:

```bash
realias
```

That's it. `realias` walks upward to find the nearest `tsconfig*.json` that
declares `compilerOptions.paths`, reads the aliases, and rewrites imports
under that tsconfig's directory.

## How it works

For each `.ts` / `.tsx` / `.js` / `.jsx` file:

1. Read the import block at the top of the file.
2. For each `import … from '<path>'`:
   - If `<path>` starts with `../` → resolve to an absolute path.
   - If `<path>` starts with `./` → skipped by default (opt in with `-a`).
   - If `<path>` already uses an alias → expand it to absolute so a more
     specific alias can be considered.
   - Otherwise (bare module like `react`, `lodash`) → leave alone.
3. Look up the absolute path in the alias table, picking the **most specific**
   match (e.g. `@v2/foo` wins over `@components/v2/foo`).
4. If the result differs from the current path, rewrite the line.
5. Stop scanning the file at the first non-empty, non-`import` line. The rest
   of the file is byte-copied through, never parsed.
6. Files with no changes are never written.

## CLI

```
realias [options]

Options:
  -c, --tsconfig FILE   Explicit tsconfig file (skips auto-discovery).
  -r, --root DIR        Directory to scan (default: dirname of tsconfig).
  -e, --exts "a b c"    Space-separated extensions
                        (default: "ts tsx js jsx").
  -s, --skip "a b c"    Space-separated directory names to prune
                        (default: "node_modules .git").
  -a, --all-relative    Also rewrite imports that start with `./`.
                        By default only `../`-style imports are touched.
  -f, --full-scan       Scan the whole file for imports instead of
                        stopping at the first non-import line. Useful
                        for files with imports mixed below other code
                        (lazy imports, post-directive imports, etc.).
  -v, --verbose         Print every file scanned and every alias loaded.
  -h, --help            Show this help.
```

Every flag can also be supplied via environment variable
(`TSCONFIG`, `ROOT_DIR`, `FILE_EXTS`, `SKIP_DIRS`, `INCLUDE_SIBLINGS`,
`FULL_SCAN`, `VERBOSE`). Flags win when both are set.

## Examples

```bash
# Default run from project root
realias

# Use a specific tsconfig
realias -c tsconfig.build.json

# Limit scan to one folder
realias -r src/components

# Rewrite ./sibling imports too
realias -a

# Scan every line, not just the top import block
realias -f

# Only TypeScript files; skip extra dirs
realias -e "ts tsx" -s "node_modules .git dist coverage"

# Verbose progress
realias -v
```

### Add to `package.json` scripts

```json
{
  "scripts": {
    "imports:fix": "realias",
    "imports:fix:all": "realias -a"
  }
}
```

## What gets rewritten

Given `tsconfig.json`:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@components/*": ["src/components/*"],
      "@v2/*":         ["src/components/v2/*"]
    }
  }
}
```

| Before                                          | After             |
| ----------------------------------------------- | ----------------- |
| `import X from '../../components/Button'`       | `'@components/Button'` |
| `import X from '../../components/v2/Modal'`     | `'@v2/Modal'`     |
| `import X from '@components/v2/Modal'`          | `'@v2/Modal'`     |
| `import X from './sibling'` *(default)*         | unchanged         |
| `import X from './sibling'` *(`-a`)*            | `'@components/Button/sibling'` *(if applicable)* |
| `import X from 'react'`                         | unchanged         |

## Caveats

- By default only the **top import block** is rewritten. Once a non-import
  line is hit, the rest of the file is copied through untouched. Pass `-f`
  to scan every line. Dynamic `import()` calls and `require(...)` are not
  rewritten in this release.
- Comment stripping in `tsconfig.json` is JSONC-aware (handles `//`, `/* */`,
  and trailing commas) but assumes no `}` characters inside the `paths`
  block.

## License

MIT