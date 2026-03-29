# Open Source Feature References

## Purpose

This document maps useful open-source product patterns to the FanyiTong roadmap.

The goal is not to clone one project. The goal is to borrow proven interaction models for:

- translation
- learning
- chat insertion
- offline support
- keyboard UX

## Keyboard and chat insertion

### FlorisBoard

Repo: [florisboard/florisboard](https://github.com/florisboard/florisboard)

Why it matters:

- modern Android IME architecture
- customizable layout system
- clean separation between input logic and keyboard UI

Borrow for FanyiTong:

- keyboard service structure
- candidate bar and action row layout ideas
- settings and enable-flow polish

### AnySoftKeyboard

Repo: [AnySoftKeyboard/AnySoftKeyboard](https://github.com/AnySoftKeyboard/AnySoftKeyboard)

Why it matters:

- mature Android keyboard behavior
- rich handling of language switching, suggestions, and special input modes

Borrow for FanyiTong:

- robust enable and switch flows
- long-press and utility key behavior
- keyboard lifecycle and edge-case handling

### Scribe-Android

Repo: [scribe-org/Scribe-Android](https://github.com/scribe-org/Scribe-Android)

Why it matters:

- keyboard built specifically for language learners
- translation, conjugation, and annotation are integrated directly into the keyboard workflow

Borrow for FanyiTong:

- translate inside the keyboard instead of leaving chat
- language-learning tools connected to typing
- future phrase presets and grammar helpers

## Translation engine and offline direction

### RTranslator

Repo: [niedev/RTranslator](https://github.com/niedev/RTranslator)

Why it matters:

- real-time Android translation
- local and privacy-friendly translation direction
- practical mobile-first architecture

Borrow for FanyiTong:

- offline translation roadmap
- on-device inference packaging ideas
- live conversation translation patterns

### LibreTranslate

Repo: [LibreTranslate/LibreTranslate](https://github.com/LibreTranslate/LibreTranslate)

Why it matters:

- open translation API with self-hostable deployment options
- useful fallback when a local model is unavailable

Borrow for FanyiTong:

- future self-hosted translation backend
- backup API strategy for chat keyboard and OCR translation

## Learning and review

### AnkiDroid

Repo: [ankidroid/Anki-Android](https://github.com/ankidroid/Anki-Android)

Why it matters:

- strong spaced repetition design
- battle-tested Android learning flows
- supports importing content from other apps

Borrow for FanyiTong:

- saved phrase review
- word-to-card conversion from translation history
- progress tracking and daily review structure

## OCR and multimodal extensions

### Tesseract OCR

Repo: [tesseract-ocr/tesseract](https://github.com/tesseract-ocr/tesseract)

Why it matters:

- open OCR base for screenshots, signs, and menus

Borrow for FanyiTong:

- screenshot-to-translation pipeline
- chat screenshot extraction before keyboard insertion

## Design references with modem and pixel flavor

These are better for visual language than for app logic.

### 98.css

Repo: [jdan/98.css](https://github.com/jdan/98.css)

Borrow for FanyiTong:

- panel borders
- title bars
- small utility surfaces

### XP.css

Repo: [botoxparty/XP.css](https://github.com/botoxparty/XP.css)

Borrow for FanyiTong:

- softer retro panels
- more mainstream-friendly visual tone

### terminal.css

Repo: [Gioni06/terminal.css](https://github.com/Gioni06/terminal.css)

Borrow for FanyiTong:

- status bar language
- modem-style chips
- utility-console visual hierarchy

## Recommended integration order

### Phase 1

- current redesigned Translate, Conversation, and Learn screens
- keyboard helper screen
- basic IME translate-and-insert flow

### Phase 2

- keyboard candidate suggestions
- saved chat snippets
- phrase tone presets
- screenshot OCR into chat composer

### Phase 3

- offline translation packs
- terminology memory
- Anki-style review scheduling
- context-aware alternative phrasing

## Product rule

FanyiTong should combine:

- the speed of a translator
- the confidence of a keyboard helper
- the retention loop of a learning app

That combination is the real differentiator.
