---
title = Lint Mode for Structural Checks
date = "2024-02-10"
tags = [lint, ci, validation]
---
# Lint Mode

Check mode runs the same structural validations without writing final output. It is useful in CI because schema and wikilink regressions fail fast. We fold these checks into the process documented in [[release-checklist]] and summarized by [[build-metrics]].
