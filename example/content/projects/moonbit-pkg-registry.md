---
title: MoonBit Package Registry Client
date: 2026-04-01
status: planned
priority: 2
homepage: https://mooncakes.io
description: A typed CLI client for the MoonBit package registry (mooncakes.io).
tags:
  - moonbit
  - tooling
---

# MoonBit Package Registry Client

A planned CLI tool for interacting with mooncakes.io — the MoonBit package registry. The goal is a typed wrapper around the registry API that surfaces package metadata, search results, and dependency graphs as structured MoonBit types rather than raw JSON.

## Motivation

The current workflow for discovering MoonBit packages is browser-based. A command-line interface would allow scripted dependency auditing, automated compatibility checks, and integration into CI pipelines.

## Status

Planned. Blocked on mooncakes.io exposing a stable public API. The design is settled: a `@registry.Package` struct with typed fields for version, dependencies, and license, parsed from the API response. The schema validation pattern from Lattice applies directly — registry responses would be validated against a declared schema before any downstream processing runs.
