AGENTS.md

MobSanté — AI Collaboration Protocol

Purpose

This repository is developed collaboratively by humans and multiple AI agents.

The goal is not to maximize code generation.

The goal is to maximize:

* product quality
* architectural consistency
* safety
* traceability
* maintainability

⸻

Source of truth

This repository contains the implementation.

The product decisions are maintained in the Obsidian knowledge base.

If documentation and implementation disagree:

* inspect the real code;
* report the discrepancy;
* never silently invent a product decision.

⸻

Human authority

Humans remain responsible for:

* product decisions
* architecture validation
* publication
* production
* roadmap priorities

AI agents assist.

They never replace product ownership.

⸻

General principles

Always prefer:

* small changes
* isolated changes
* reversible changes
* explicit code
* readable code
* tested code

Avoid:

* speculative refactoring
* unrelated cleanup
* hidden behaviour changes
* architecture redesign outside scope

⸻

Facts over assumptions

For MobSanté:

* facts are stronger than declarations;
* an unverified fact remains unavailable;
* uncertainty must be reported;
* never invent missing information.

⸻

Repository workflow

Before modifying code:

1. Inspect the repository.
2. Read the relevant files.
3. Check existing local changes.
4. Understand the requested scope.

Never assume.

Investigate first.

⸻

Protected work

Existing local work may already be present.

Never:

* overwrite it;
* reset it;
* include it accidentally in another task.

If isolation is impossible:

STOP.

Explain why.

⸻

Allowed

AI agents may:

* inspect the repository;
* analyse architecture;
* modify local code;
* create tests;
* improve documentation;
* execute approved local development commands;
* prepare implementation reports.

⸻

Forbidden without explicit human approval

Never:

* git commit
* git push
* merge
* tag
* deploy
* publish
* modify production data
* modify secrets
* perform production migrations
* make irreversible changes
* make product decisions

If a task requires one of these actions:

STOP.

⸻

Reports

When requested, reports must be written to:

.ai/output/

Reports should clearly separate:

* facts
* observations
* risks
* recommendations
* decisions required

⸻

Product philosophy

MobSanté does not evaluate people.

MobSanté evaluates mobilisation.

The objective is to help organisations mobilise verified healthcare professionals quickly while preserving:

* autonomy
* fairness
* traceability
* trust

Simplicity is a feature.

⸻

Completion

At the end of every task:

* summarise the work;
* list modified files;
* list executed tests;
* identify remaining risks;
* stop.

Never continue with another task unless explicitly requested.